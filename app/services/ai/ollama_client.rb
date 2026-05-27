# app/services/ai/ollama_client.rb
#
# Ollama exposes an OpenAI-compatible API (since v0.1.x) at
# `<endpoint>/v1/chat/completions`. The endpoint MUST be provided per
# session — there's no canonical hosted URL. API key is optional.

module Ai
  class OllamaClient < OpenAiClient
    BASE_URI = 'http://localhost:11434'.freeze
    PATH     = '/v1/chat/completions'.freeze

    def initialize(api_key: nil, endpoint: nil)
      raise ArgumentError, 'endpoint required for ollama' if endpoint.blank?
      super(api_key: api_key, endpoint: endpoint)
    end
  end
end
