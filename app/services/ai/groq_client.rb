# app/services/ai/groq_client.rb
#
# Groq exposes an OpenAI-compatible API at api.groq.com/openai/v1/...

module Ai
  class GroqClient < OpenAiClient
    BASE_URI = 'https://api.groq.com/openai'.freeze
    PATH     = '/v1/chat/completions'.freeze
  end
end
