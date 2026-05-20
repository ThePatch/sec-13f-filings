# app/models/ai_insight.rb
#
# Pre-generated insights produced by the GenerateInsightsJob (owned by the
# Insights agent). The AI controller exposes a read-only index endpoint
# over this table.

class AiInsight < ApplicationRecord
  KINDS = %w[rotation new crowding anomaly exit].freeze

  validates :kind, inclusion: { in: KINDS }
  validates :headline, :body, :model, presence: true

  scope :recent, ->(limit = 50) { order(created_at: :desc).limit(limit) }
  scope :of_kind, ->(k) { where(kind: k) if k.present? }
  scope :since_time, ->(ts) { where('created_at >= ?', ts) if ts.present? }
end
