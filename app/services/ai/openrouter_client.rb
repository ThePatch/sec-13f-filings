# app/services/ai/openrouter_client.rb
#
# OpenRouter is OpenAI-compatible. The user may supply a custom `endpoint`
# (e.g. a self-hosted proxy) which overrides BASE_URI via the parent ctor.

module Ai
  class OpenRouterClient < OpenAiClient
    BASE_URI = 'https://openrouter.ai/api'.freeze
    PATH     = '/v1/chat/completions'.freeze
  end
end
