# app/controllers/api/ai/lab_controller.rb
#
# Fans the same prompt out across N (provider, model) pairs in parallel
# threads. Returns Record<"provider:model", AIMessage>.
#
# We use plain Threads + ConnectionPool.with_connection-free DB access
# (the router only does AR lookups in the parent thread before spawning).
# To keep DB usage off the worker threads, we pre-resolve provider configs
# in the main thread and pass plain values into each worker.
#
# Result shape matches the frontend's lab_run() contract.

module Api
  module Ai
    class LabController < Api::BaseController
      MAX_FANOUT = 8

      def run
        models = Array(params[:models])
        if models.empty?
          return render(json: { error: 'bad_request', message: 'models[] required' }, status: :bad_request)
        end
        if models.size > MAX_FANOUT
          return render(json: { error: 'too_many', message: "max #{MAX_FANOUT} models" }, status: :bad_request)
        end

        messages = chat_messages
        context  = chat_context
        sid      = session_id

        results = {}
        mutex   = Mutex.new

        threads = models.map do |m|
          h = m.respond_to?(:to_unsafe_h) ? m.to_unsafe_h : m
          provider = h[:provider] || h['provider']
          model    = h[:model]    || h['model']
          key      = "#{provider}:#{model}"

          Thread.new do
            begin
              ActiveRecord::Base.connection_pool.with_connection do
                msg = ::Ai::Router.new(session_id: sid).chat(
                  provider: provider, model: model, messages: messages, context: context,
                )
                mutex.synchronize { results[key] = msg }
              end
            rescue => e
              mutex.synchronize do
                results[key] = {
                  id: SecureRandom.uuid,
                  role: 'assistant',
                  body: nil,
                  model: { provider: provider, model: model },
                  error: e.message,
                  created_at: Time.current.iso8601,
                }
              end
            end
          end
        end

        threads.each(&:join)
        render json: results
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
