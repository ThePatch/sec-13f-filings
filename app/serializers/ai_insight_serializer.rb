# app/serializers/ai_insight_serializer.rb
#
# Shape matches the `AIInsight` interface in frontend/src/types/index.ts
# and the `GET /api/ai/insights` contract in frontend/docs/API_CONTRACT.md.
class AiInsightSerializer
  def initialize(insight)
    @insight = insight
  end

  def serializable_hash
    {
      id: @insight.id.to_s,
      kind: @insight.kind,
      filer: filer_block,
      cusip: @insight.cusip,
      headline: @insight.headline,
      body: @insight.body,
      tags: Array(@insight.tags),
      confidence: @insight.confidence,
      model: @insight.model,
      created_at: @insight.created_at&.iso8601,
    }
  end

  private

  def filer_block
    return nil if @insight.filer_cik.blank? && @insight.filer_name.blank?
    {
      cik: @insight.filer_cik,
      name: @insight.filer_name,
    }
  end
end
