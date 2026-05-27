# app/services/ai/nim_client.rb
#
# NVIDIA NIM is OpenAI-compatible. Hosted endpoint is integrate.api.nvidia.com.

module Ai
  class NimClient < OpenAiClient
    BASE_URI = 'https://integrate.api.nvidia.com'.freeze
    PATH     = '/v1/chat/completions'.freeze
  end
end
