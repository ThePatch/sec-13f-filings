# app/serializers/filer_detail_serializer.rb
# Fatter serializer for the filer detail page.
class FilerDetailSerializer
  def initialize(filer, params: {})
    @filer = filer
    @latest = params[:latest]
  end

  def serializable_hash
    {
      cik: @filer.cik,
      name: @filer.name,
      city: @filer.city,
      state_or_country: @filer.state_or_country,
      most_recent_date_filed: @filer.most_recent_date_filed&.iso8601,
      filings_count: @filer.filings_count,
      tags: classify_tags,
      aum: @latest&.holdings_value_calculated&.to_s,
      qoq_pct: qoq_pct,
      positions_count: @latest&.aggregate_holdings_count,
      top_position_label: top_position_label,
    }
  end

  private

  def classify_tags
    # TODO: replace heuristic with LLM-classified tags or a manual mapping table.
    name = @filer.name.downcase
    tags = []
    tags << 'mega-cap' if (@latest&.holdings_value_calculated || 0).to_f > 1e12
    tags << 'quant' if name.match?(/renaissance|two sigma|citadel|millennium|de shaw/)
    tags << 'index' if name.match?(/vanguard|blackrock|state street/)
    tags << 'macro' if name.match?(/bridgewater|soros/)
    tags << 'activist' if name.match?(/pershing|elliott|trian/)
    tags << 'growth' if name.match?(/tiger global|coatue|ark/)
    tags << 'value' if name.match?(/berkshire/)
    tags << 'multi-strat' if name.match?(/citadel|millennium/)
    tags.uniq
  end

  def qoq_pct
    return nil unless @latest
    prev = ThirteenF.where(cik: @filer.cik)
                    .where('report_date < ?', @latest.report_date)
                    .order(report_date: :desc)
                    .first
    return nil unless prev&.holdings_value_calculated
    ((@latest.holdings_value_calculated - prev.holdings_value_calculated) / prev.holdings_value_calculated * 100).to_f.round(2)
  end

  def top_position_label
    return nil unless @latest
    top = AggregateHolding.where(thirteen_f_id: @latest.id).order(value: :desc).first
    return nil unless top
    pct = (top.value.to_f / @latest.holdings_value_calculated.to_f * 100).round(1)
    "#{top.issuer_name} — #{pct}%"
  end
end
