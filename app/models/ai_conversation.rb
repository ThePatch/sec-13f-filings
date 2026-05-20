# app/models/ai_conversation.rb
class AiConversation < ApplicationRecord
  validates :session_id, presence: true

  # messages and context are jsonb arrays — default [] from the schema.
  before_validation :ensure_defaults

  scope :for_session, ->(sid) { where(session_id: sid).order(updated_at: :desc) }

  private

  def ensure_defaults
    self.messages ||= []
    self.context  ||= []
  end
end
