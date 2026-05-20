# app/controllers/api/ai/insights_controller.rb
#
# Read-only proxy over the ai_insights table. The Insights agent owns
# GenerateInsightsJob which populates it on a clockwork schedule.
#
# Query params:
#   kind   — filter by kind (rotation|new|crowding|anomaly|exit)
#   since  — ISO datetime, returns insights newer than this
#   limit  — max rows (default 50, clamped 1..200)

module Api
  module Ai
    class InsightsController < Api::BaseController
      def index
        scope = AiInsight.all
        scope = scope.of_kind(params[:kind])     if params[:kind].present?
        scope = scope.since_time(parse_since)    if params[:since].present?
        limit = (params[:limit] || 50).to_i.clamp(1, 200)
        scope = scope.order(created_at: :desc).limit(limit)

        render json: scope.map { |i| serialize(i) }
      end

      private

      # Defer to AiInsightSerializer if present (owned by the Insights agent);
      # otherwise emit a sensible default so this endpoint works in isolation.
      def serialize(insight)
        if defined?(AiInsightSerializer)
          AiInsightSerializer.new(insight).serializable_hash
        else
          {
            id:         insight.id.to_s,
            kind:       insight.kind,
            filer_cik:  insight.filer_cik,
            filer_name: insight.filer_name,
            cusip:      insight.cusip,
            headline:   insight.headline,
            body:       insight.body,
            tags:       insight.tags,
            confidence: insight.confidence,
            model:      insight.model,
            created_at: insight.created_at&.iso8601,
          }
        end
      end

      def parse_since
        Time.iso8601(params[:since])
      rescue ArgumentError
        nil
      end
    end
  end
end
