# app/services/ai/openai_client.rb
#
# OpenAI + OpenAI-compatible providers (Groq, OpenRouter, NIM, Ollama all
# subclass this and override BASE_URI). Per-instance @base avoids mutating
# the class-level HTTParty base_uri across concurrent requests.

require 'httparty'
require 'json'

module Ai
  class OpenAiClient
    include HTTParty
    default_timeout 60

    BASE_URI = 'https://api.openai.com'.freeze
    PATH     = '/v1/chat/completions'.freeze

    def initialize(api_key:, endpoint: nil)
      @api_key = api_key
      @base    = endpoint.presence || self.class::BASE_URI
      @headers = build_headers(api_key)
    end

    def chat(messages:, model:, system_prompt: nil, max_tokens: 1024)
      msgs = messages.map { |m| { role: m[:role] || m['role'], content: m[:content] || m['content'] } }
      msgs.unshift(role: 'system', content: system_prompt) if system_prompt

      t0 = Time.now
      response = HTTParty.post(
        "#{@base}#{self.class::PATH}",
        body: { model: model, messages: msgs, max_tokens: max_tokens }.to_json,
        headers: @headers,
        timeout: 60,
      )
      latency_ms = ((Time.now - t0) * 1000).to_i
      raise "#{self.class.name} error: #{response.code} #{response.body}" unless response.success?
      data = response.parsed_response

      {
        body: data.dig('choices', 0, 'message', 'content'),
        tokens_in:  data.dig('usage', 'prompt_tokens'),
        tokens_out: data.dig('usage', 'completion_tokens'),
        latency_ms: latency_ms,
        cost_usd: 0.0,
      }
    end

    # OpenAI-compatible SSE streaming. Each event is
    #   data: {"choices":[{"delta":{"content":"..."}}]}
    # terminated by `data: [DONE]`.
    def stream_chat(messages:, model:, system_prompt: nil, max_tokens: 1024)
      msgs = messages.map { |m| { role: m[:role] || m['role'], content: m[:content] || m['content'] } }
      msgs.unshift(role: 'system', content: system_prompt) if system_prompt

      buf = ''
      output_tokens = 0
      t0 = Time.now

      HTTParty.post(
        "#{@base}#{self.class::PATH}",
        body: { model: model, messages: msgs, max_tokens: max_tokens, stream: true }.to_json,
        headers: @headers,
        stream_body: true,
        timeout: 120,
      ) do |chunk|
        buf << chunk
        while (idx = buf.index("\n\n"))
          event = buf.slice!(0..idx + 1)
          line = event.lines.find { |l| l.start_with?('data: ') }
          next unless line
          json = line.sub('data: ', '').strip
          next if json.empty?
          break if json == '[DONE]'

          begin
            data = JSON.parse(json)
          rescue JSON::ParserError
            next
          end
          delta = data.dig('choices', 0, 'delta', 'content')
          if delta
            output_tokens += 1
            yield(delta: delta)
          end
          if (usage = data['usage'])
            output_tokens = usage['completion_tokens'] || output_tokens
          end
        end
      end

      latency_ms = ((Time.now - t0) * 1000).to_i
      yield(done: true, tokens_in: nil, tokens_out: output_tokens, latency_ms: latency_ms)
    end

    private

    def build_headers(api_key)
      h = { 'Content-Type' => 'application/json' }
      h['Authorization'] = "Bearer #{api_key}" if api_key.present?
      h
    end
  end
end
