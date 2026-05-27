# app/services/ai/router.rb
#
# Dispatches chat requests to the right provider client. Each client
# implements #chat and #stream_chat with the same signature. The router
# also handles context resolution (filer/filing/cusip/period refs) by
# loading the actual records and folding them into the system prompt.

module Ai
  class Router
    PROVIDERS = {
      'claude'     => 'Ai::AnthropicClient',
      'openai'     => 'Ai::OpenAiClient',
      'groq'       => 'Ai::GroqClient',
      'openrouter' => 'Ai::OpenRouterClient',
      'nim'        => 'Ai::NimClient',
      'ollama'     => 'Ai::OllamaClient',
    }.freeze

    def initialize(session_id:)
      @session_id = session_id
    end

    def chat(provider:, model:, messages:, context: [], **opts)
      client = client_for(provider)
      system_prompt = ContextBuilder.new.build(context)
      result = client.chat(messages: messages, model: model, system_prompt: system_prompt, **opts)
      touch_config(provider)
      message_record(provider: provider, model: model, result: result, context: context)
    end

    def stream_chat(provider:, model:, messages:, context: [], **opts, &block)
      client = client_for(provider)
      system_prompt = ContextBuilder.new.build(context)
      result = client.stream_chat(messages: messages, model: model, system_prompt: system_prompt, **opts, &block)
      touch_config(provider)
      result
    end

    private

    def client_for(provider)
      klass_name = PROVIDERS[provider.to_s] || raise(ArgumentError, "unknown provider: #{provider}")
      config = AiProviderConfig.find_by(session_id: @session_id, provider: provider.to_s)
      key = config&.api_key
      if key.blank? && provider.to_s != 'ollama'
        raise "no api key configured for #{provider}"
      end
      klass = klass_name.constantize
      klass.new(api_key: key, endpoint: config&.endpoint)
    end

    def touch_config(provider)
      AiProviderConfig.where(session_id: @session_id, provider: provider.to_s).update_all(last_used_at: Time.current)
    end

    def message_record(provider:, model:, result:, context:)
      {
        id: SecureRandom.uuid,
        role: 'assistant',
        body: result[:body],
        model: { provider: provider, model: model },
        tokens_in: result[:tokens_in],
        tokens_out: result[:tokens_out],
        cost_usd: result[:cost_usd],
        latency_ms: result[:latency_ms],
        citations: context.map { |c| { ref_type: c[:ref_type], ref_id: c[:ref_id], label: c[:ref_type].to_s } },
        created_at: Time.current.iso8601,
      }
    end
  end

  # Resolves "context refs" into a system prompt with actual filing/holding data.
  class ContextBuilder
    SYSTEM_BASE = <<~SYS.freeze
      You are an AI assistant analyzing SEC Form 13F institutional holdings filings.
      Be concise, factual, and numerical. When citing values, use the actual numbers
      from the context blocks below — never invent data.

      Format responses as HTML with <b>, <i>, <span class="pos|neg|mono">.
      Numbers in the body should use the same units as the source data.
    SYS

    def build(context_refs)
      return SYSTEM_BASE if context_refs.blank?

      blocks = Array(context_refs).map do |ref|
        type = (ref[:ref_type] || ref['ref_type']).to_s
        id   = ref[:ref_id]   || ref['ref_id']
        case type
        when 'filer'   then build_filer_block(id)
        when 'filing'  then build_filing_block(id)
        when 'cusip', 'holding' then build_cusip_block(id)
        when 'period'  then build_period_block(id)
        end
      end.compact

      return SYSTEM_BASE if blocks.empty?
      "#{SYSTEM_BASE}\n\nCONTEXT BLOCKS:\n#{blocks.join("\n\n")}"
    end

    private

    def build_filer_block(cik)
      filer = ThirteenFFiler.find_by(cik: cik)
      return nil unless filer
      latest = ThirteenF.where(cik: cik).order(date_filed: :desc).first
      payload = {
        cik: filer.cik, name: filer.name,
        latest_filing: latest&.as_json(except: heavy_columns(ThirteenF)),
      }
      "FILER #{filer.name} (CIK #{cik})\n#{payload.to_json}"
    end

    def build_filing_block(filing_id)
      f = ThirteenF.find_by(id: filing_id)
      return nil unless f
      holdings = AggregateHolding.where(thirteen_f_id: f.id).order(value: :desc).limit(50).as_json
      payload = f.as_json(except: heavy_columns(ThirteenF)).merge(top_holdings: holdings)
      label = "#{f.try(:name) || f.cik} #{f.try(:report_year)}-Q#{f.try(:report_quarter)}"
      "FILING #{label}\n#{payload.to_json}"
    end

    def build_cusip_block(cusip)
      lookup = CompanyCusipLookup.find_by(cusip: cusip)
      return nil unless lookup
      "CUSIP #{cusip} (#{lookup.try(:symbol)} — #{lookup.try(:issuer_name) || lookup.try(:name)})"
    end

    def build_period_block(period)
      "PERIOD #{period}"
    end

    # Exclude raw XML / large blobs if columns happen to exist.
    def heavy_columns(klass)
      (%i[primary_doc_xml info_table_xml] & klass.column_names.map(&:to_sym))
    end
  end
end
