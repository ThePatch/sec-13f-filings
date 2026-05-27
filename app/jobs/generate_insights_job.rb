# app/jobs/generate_insights_job.rb
#
# Runs hourly via clock.rb. For every ThirteenF whose XML was just processed,
# diff it against the previous quarter's filing for the same CIK, ship the
# diff + a prompt template to Claude, and persist the resulting AiInsight rows.
#
# Idempotency: skips if an AiInsight already exists for the (filer_cik, period)
# tuple, where "period" is encoded as report_year/report_quarter in payload.
#
# Bypasses Ai::Router (which requires a per-session AiProviderConfig row)
# and calls Ai::AnthropicClient directly with ENV['ANTHROPIC_API_KEY'] —
# this is a cron-driven job with no session.
class GenerateInsightsJob < ApplicationJob
  queue_as :default

  PROMPT_PATH = Rails.root.join("app", "prompts", "insight.md")
  LOOKBACK    = 65.minutes
  TOP_N       = 40
  MODEL_ENV   = "INSIGHTS_MODEL"
  DEFAULT_MODEL = "claude-sonnet-4-6"

  def perform
    # The fork's ThirteenF uses `xml_data_fetched_at` as its "processed_at".
    cutoff = LOOKBACK.ago
    recent = ThirteenF.where("xml_data_fetched_at > ?", cutoff)
                      .where.not(report_year: nil)
                      .where.not(report_quarter: nil)
                      .limit(50)

    recent.find_each do |filing|
      next if insight_already_exists?(filing)

      prev = previous_filing_for(filing)
      next unless prev

      begin
        generate_for(filing, prev)
      rescue => e
        Rails.logger.error("[GenerateInsightsJob] filing=#{filing.id} #{e.class}: #{e.message}")
      end
    end
  end

  private

  def insight_already_exists?(filing)
    AiInsight.where(filer_cik: filing.cik)
             .where("payload ->> 'report_year' = ?", filing.report_year.to_s)
             .where("payload ->> 'report_quarter' = ?", filing.report_quarter.to_s)
             .exists?
  end

  def previous_filing_for(filing)
    # Brief says: order by period_of_report desc; in this fork that's report_date.
    ThirteenF.where(cik: filing.cik)
             .where("report_date < ?", filing.report_date)
             .where.not(xml_data_fetched_at: nil)
             .order(report_date: :desc)
             .first
  end

  def generate_for(filing, prev)
    diff      = build_diff(filing, prev)
    prompt    = render_prompt(filing, prev)
    sys_block = system_context(filing, prev, diff)

    api_key = ENV["ANTHROPIC_API_KEY"]
    if api_key.blank?
      Rails.logger.warn("[GenerateInsightsJob] ANTHROPIC_API_KEY not set; skipping #{filing.id}")
      return
    end

    client = Ai::AnthropicClient.new(api_key: api_key)
    result = client.chat(
      messages: [{ role: "user", content: prompt }],
      model: model_name,
      system_prompt: sys_block,
    )

    parsed = parse_response(result.is_a?(Hash) ? (result[:body] || result["body"]) : result.to_s)
    return if parsed.blank?

    Array(parsed).each do |insight|
      persist_insight(filing, prev, insight)
    end
  end

  # ── Diff computation ────────────────────────────────────────────────
  def build_diff(filing, prev)
    curr_h = AggregateHolding.where(thirteen_f_id: filing.id).order(value: :desc).limit(200).to_a
    prev_h = AggregateHolding.where(thirteen_f_id: prev.id).order(value: :desc).limit(200).to_a

    curr_by = curr_h.index_by(&:cusip)
    prev_by = prev_h.index_by(&:cusip)

    new_positions = (curr_by.keys - prev_by.keys).map { |c| holding_summary(curr_by[c]) }
    exits         = (prev_by.keys - curr_by.keys).map { |c| holding_summary(prev_by[c]) }

    size_changes = curr_by.keys.intersection(prev_by.keys).map do |c|
      a = curr_by[c]; b = prev_by[c]
      delta = a.value.to_f - b.value.to_f
      pct   = b.value.to_f.zero? ? nil : (delta / b.value.to_f * 100.0).round(2)
      {
        cusip: c,
        issuer: a.issuer_name,
        prev_value: b.value,
        curr_value: a.value,
        delta_value: delta,
        delta_pct: pct,
      }
    end.sort_by { |h| -h[:delta_value].abs }.first(TOP_N)

    {
      new_positions: new_positions.first(TOP_N),
      exits: exits.first(TOP_N),
      top_size_changes: size_changes,
    }
  end

  def holding_summary(h)
    {
      cusip: h.cusip,
      issuer: h.issuer_name,
      value: h.value,
      shares_or_principal_amount: h.shares_or_principal_amount,
      shares_or_principal_amount_type: h.shares_or_principal_amount_type,
    }
  end

  # ── Prompt assembly ─────────────────────────────────────────────────
  def render_prompt(filing, prev)
    template = File.read(PROMPT_PATH)
    template.gsub("{{filer_name}}", filing.name.to_s)
            .gsub("{{current_period}}", period_label(filing))
            .gsub("{{previous_period}}", period_label(prev))
  end

  def period_label(f)
    "#{f.report_year}-Q#{f.report_quarter}"
  end

  def system_context(filing, prev, diff)
    [
      "CURRENT FILING: #{filing.name} (#{period_label(filing)}) — CIK #{filing.cik}",
      "PREVIOUS FILING: #{prev.name} (#{period_label(prev)}) — CIK #{prev.cik}",
      "DIFF JSON:",
      diff.to_json,
    ].join("\n\n")
  end

  # ── Response parsing ────────────────────────────────────────────────
  # The prompt returns ONE JSON object, but allow an array for forward-compat.
  def parse_response(body)
    return nil if body.blank?
    # Strip fenced code blocks if present, then grab the JSON.
    cleaned = body.to_s.gsub(/```(?:json)?/, "").strip
    json_str =
      if cleaned.start_with?("[")
        cleaned[/\[.*\]/m]
      else
        cleaned[/\{.*\}/m]
      end
    return nil unless json_str
    JSON.parse(json_str, symbolize_names: true)
  rescue JSON::ParserError => e
    Rails.logger.warn("[GenerateInsightsJob] bad JSON: #{e.message}")
    nil
  end

  # ── Persistence ─────────────────────────────────────────────────────
  def persist_insight(filing, prev, insight)
    kind = insight[:kind].to_s
    return unless %w[rotation new exit crowding anomaly].include?(kind)

    AiInsight.create!(
      kind: kind,
      filer_cik: filing.cik,
      filer_name: filing.name,
      cusip: Array(insight[:tags]).find { |t| t.is_a?(String) && t.match?(/\A[A-Z0-9]{9}\z/) },
      headline: insight[:headline].to_s.first(500),
      body: insight[:body].to_s,
      tags: Array(insight[:tags]).map(&:to_s),
      confidence: (insight[:confidence] || 0.6).to_f,
      model: model_name,
      payload: {
        filing_id: filing.id,
        prev_filing_id: prev.id,
        report_year: filing.report_year,
        report_quarter: filing.report_quarter,
      },
    )
  end

  def model_name
    ENV.fetch(MODEL_ENV, DEFAULT_MODEL)
  end
end
