# app/controllers/api/ai/providers_controller.rb
module Api
  module Ai
    class ProvidersController < Api::BaseController
      ALL_PROVIDERS = %w[claude openai groq openrouter nim ollama].freeze

      MODELS = {
        'claude'     => %w[claude-sonnet-4-5 claude-opus-4 claude-haiku-4-5],
        'openai'     => %w[gpt-4o gpt-4o-mini o1-preview],
        'groq'       => %w[llama-3.3-70b-versatile mixtral-8x7b-32768 deepseek-r1-distill-llama-70b],
        'openrouter' => %w[anthropic/claude-3.5-sonnet mistralai/mistral-large qwen/qwen-2.5-72b-instruct],
        'nim'        => %w[nvidia/llama-3.1-nemotron-70b-instruct],
        'ollama'     => %w[llama3.3:70b qwen2.5:32b deepseek-r1:32b],
      }.freeze

      PRETTY = {
        'claude'     => 'Anthropic Claude',
        'openai'     => 'OpenAI',
        'groq'       => 'Groq',
        'openrouter' => 'OpenRouter',
        'nim'        => 'NVIDIA NIM',
        'ollama'     => 'Ollama (local)',
      }.freeze

      def index
        configs = AiProviderConfig.where(session_id: session_id).index_by(&:provider)
        payload = ALL_PROVIDERS.map do |p|
          c = configs[p]
          key = c&.api_key
          connected = key.present? || p == 'ollama'
          {
            id: p,
            name: PRETTY[p],
            status: connected ? 'connected' : 'disconnected',
            models: MODELS[p],
            default_model: c&.default_model || MODELS[p].first,
            endpoint: c&.endpoint,
            latency_ms: nil,
            last_used_at: c&.last_used_at&.iso8601,
            api_key_last4: key.to_s.last(4).presence,
          }
        end
        render json: payload
      end

      def update
        return render_unknown_provider unless ALL_PROVIDERS.include?(params[:id])
        config = AiProviderConfig.find_or_initialize_by(session_id: session_id, provider: params[:id])
        config.api_key       = params[:api_key]       if params.key?(:api_key)
        config.default_model = params[:default_model] if params.key?(:default_model)
        config.endpoint      = params[:endpoint]      if params.key?(:endpoint)
        config.save!
        render json: { ok: true }
      end

      def test
        provider = params[:id]
        return render_unknown_provider unless ALL_PROVIDERS.include?(provider)
        config = AiProviderConfig.find_by(session_id: session_id, provider: provider)
        if provider != 'ollama' && config&.api_key.blank?
          return render(json: { ok: false, message: 'no key' }, status: :bad_request)
        end

        t0 = Time.now
        ::Ai::Router.new(session_id: session_id).chat(
          provider: provider,
          model: config&.default_model || MODELS[provider].first,
          messages: [{ role: 'user', content: 'reply with just "pong"' }],
          max_tokens: 16,
        )
        latency_ms = ((Time.now - t0) * 1000).to_i
        render json: { ok: true, latency_ms: latency_ms, model_count: MODELS[provider].size }
      rescue => e
        render json: { ok: false, message: e.message }, status: :unprocessable_entity
      end

      def default_model
        return render_unknown_provider unless ALL_PROVIDERS.include?(params[:id])
        config = AiProviderConfig.find_or_initialize_by(session_id: session_id, provider: params[:id])
        config.update!(default_model: params[:model])
        render json: { ok: true }
      end

      private

      def render_unknown_provider
        render json: { error: 'unknown_provider', message: "unknown provider: #{params[:id]}" },
               status: :bad_request
      end
    end
  end
end
