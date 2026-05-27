# app/controllers/api/ai/conversations_controller.rb
#
# REST CRUD for the ChatScreen right-rail conversation history. All scoped
# to the current cookie session_id — no cross-session reads.

module Api
  module Ai
    class ConversationsController < Api::BaseController
      before_action :load_conversation, only: %i[show update destroy]

      def index
        scope = AiConversation.for_session(session_id)
        render json: scope.map { |c| AiConversationSerializer.new(c).serializable_hash }
      end

      def show
        render json: AiConversationSerializer.new(@conversation).serializable_hash
      end

      def create
        convo = AiConversation.new(
          session_id: session_id,
          title:      params[:title].presence || default_title,
          messages:   Array(params[:messages]).map { |m| coerce(m) },
          context:    Array(params[:context]).map  { |c| coerce(c) },
        )
        convo.save!
        render json: AiConversationSerializer.new(convo).serializable_hash, status: :created
      end

      def update
        @conversation.title    = params[:title]                                       if params.key?(:title)
        @conversation.messages = Array(params[:messages]).map { |m| coerce(m) }       if params.key?(:messages)
        @conversation.context  = Array(params[:context]).map  { |c| coerce(c) }       if params.key?(:context)
        @conversation.save!
        render json: AiConversationSerializer.new(@conversation).serializable_hash
      end

      def destroy
        @conversation.destroy!
        head :no_content
      end

      private

      def load_conversation
        @conversation = AiConversation.where(session_id: session_id).find(params[:id])
      end

      def coerce(obj)
        return obj if obj.is_a?(Hash)
        obj.respond_to?(:to_unsafe_h) ? obj.to_unsafe_h : obj.to_h
      end

      def default_title
        "Conversation #{Time.current.strftime('%b %-d, %H:%M')}"
      end
    end
  end
end
