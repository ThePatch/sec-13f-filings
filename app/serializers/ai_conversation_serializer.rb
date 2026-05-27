# app/serializers/ai_conversation_serializer.rb
class AiConversationSerializer
  def initialize(convo)
    @c = convo
  end

  def serializable_hash
    {
      id:         @c.id,
      title:      @c.title,
      messages:   @c.messages,
      context:    @c.context,
      created_at: @c.created_at&.iso8601,
      updated_at: @c.updated_at&.iso8601,
    }
  end
end
