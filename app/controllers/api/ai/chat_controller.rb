# app/controllers/api/ai/chat_controller.rb
#
# Two endpoints:
#   POST /api/ai/chat         — single-shot, returns the AIMessage JSON
#   POST /api/ai/chat/stream  — SSE; emits {delta:} events and ends with
#                               {done:true, msg:{...}} followed by [DONE].
#
# The SSE payload format matches frontend/src/api/ai.ts:streamChat exactly.

module Api
  module Ai
    class ChatController < Api::BaseController
      include ActionController::Live

      def create
        msg = ::Ai::Router.new(session_id: session_id).chat(
          provider: params[:provider],
          model: params[:model],
          messages: chat_messages,
          context: chat_context,
        )
        render json: msg
      rescue ArgumentError => e
        render json: { error: 'bad_request', message: e.message }, status: :bad_request
      rescue => e
        render json: { error: 'provider_error', message: e.message }, status: :bad_gateway
      end

      def stream
        response.headers['Content-Type']     = 'text/event-stream'
        response.headers['Cache-Control']    = 'no-cache'
        response.headers['X-Accel-Buffering'] = 'no'
        response.headers['Connection']       = 'keep-alive'

        provider = params[:provider]
        model    = params[:model]
        full_body = +''
        tokens_in = tokens_out = latency = nil

        ::Ai::Router.new(session_id: session_id).stream_chat(
          provider: provider,
          model: model,
          messages: chat_messages,
          context: chat_context,
        ) do |event|
          if event[:delta]
            full_body << event[:delta]
            response.stream.write("data: #{ { delta: event[:delta] }.to_json }\n\n")
          elsif event[:done]
            tokens_in  = event[:tokens_in]
            tokens_out = event[:tokens_out]
            latency    = event[:latency_ms]
            final_msg = {
              id: SecureRandom.uuid,
              role: 'assistant',
              body: full_body,
              model: { provider: provider, model: model },
              tokens_in: tokens_in,
              tokens_out: tokens_out,
              latency_ms: latency,
              created_at: Time.current.iso8601,
            }
            response.stream.write("data: #{ { done: true, msg: final_msg }.to_json }\n\n")
          end
        end

        response.stream.write("data: [DONE]\n\n")
      rescue => e
        # Best-effort error frame so the client doesn't hang.
        begin
          response.stream.write("data: #{ { error: e.message }.to_json }\n\n")
        rescue IOError
          # connection already closed
        end
      ensure
        response.stream.close
      end

      private

      def chat_messages
        raw = params[:messages]
        raise ActionController::ParameterMissing.new(:messages) if raw.blank?
        Array(raw).map do |m|
          h = m.respond_to?(:to_unsafe_h) ? m.to_unsafe_h : m
          { role: h[:role] || h['role'], content: h[:content] || h['content'] }
        end
      end

      def chat_context
        Array(params[:context]).map do |c|
          h = c.respond_to?(:to_unsafe_h) ? c.to_unsafe_h : c
          { ref_type: h[:ref_type] || h['ref_type'], ref_id: h[:ref_id] || h['ref_id'] }
        end
      end
    end
  end
end
