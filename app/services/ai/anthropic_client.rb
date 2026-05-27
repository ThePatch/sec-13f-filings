# app/services/ai/anthropic_client.rb
#
# Anthropic Claude — REST + SSE streaming. Calls api.anthropic.com directly
# via httparty (already in Gemfile); we deliberately avoid the official
# anthropic Ruby SDK to keep dependencies minimal.

require 'httparty'
require 'json'
require 'securerandom'

module Ai
  class AnthropicClient
    include HTTParty
    default_timeout 60

    BASE_URI = 'https://api.anthropic.com'.freeze

    def initialize(api_key:, endpoint: nil)
      raise ArgumentError, 'api_key required' unless api_key
      @base = endpoint.presence || BASE_URI
      @headers = {
        'Content-Type'      => 'application/json',
        'x-api-key'         => api_key,
        'anthropic-version' => '2023-06-01',
      }
    end

    # @return [Hash] {body, tokens_in, tokens_out, latency_ms, cost_usd}
    def chat(messages:, model:, system_prompt: nil, max_tokens: 1024)
      payload = {
        model: model,
        max_tokens: max_tokens,
        messages: messages.map { |m| { role: m[:role] || m['role'], content: m[:content] || m['content'] } },
      }
      payload[:system] = system_prompt if system_prompt

      t0 = Time.now
      response = HTTParty.post("#{@base}/v1/messages", body: payload.to_json, headers: @headers, timeout: 60)
      latency_ms = ((Time.now - t0) * 1000).to_i

      raise "Anthropic error: #{response.code} #{response.body}" unless response.success?
      data = response.parsed_response

      {
        body: data.dig('content', 0, 'text'),
        tokens_in:  data.dig('usage', 'input_tokens'),
        tokens_out: data.dig('usage', 'output_tokens'),
        latency_ms: latency_ms,
        cost_usd: estimate_cost(model, data['usage'] || {}),
      }
    end

    # Streams via SSE — yields {delta:} hashes then a final {done: true, ...}.
    def stream_chat(messages:, model:, system_prompt: nil, max_tokens: 1024)
      payload = {
        model: model, max_tokens: max_tokens, stream: true,
        messages: messages.map { |m| { role: m[:role] || m['role'], content: m[:content] || m['content'] } },
      }
      payload[:system] = system_prompt if system_prompt

      buf = ''
      input_tokens = 0
      output_tokens = 0
      t0 = Time.now

      HTTParty.post(
        "#{@base}/v1/messages",
        body: payload.to_json,
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
          next if json.empty? || json == '[DONE]'

          begin
            data = JSON.parse(json)
          rescue JSON::ParserError
            next
          end

          case data['type']
          when 'content_block_delta'
            delta = data.dig('delta', 'text')
            yield(delta: delta) if delta
          when 'message_start'
            input_tokens = data.dig('message', 'usage', 'input_tokens') || input_tokens
          when 'message_delta'
            output_tokens = data.dig('usage', 'output_tokens') || output_tokens
          end
        end
      end

      latency_ms = ((Time.now - t0) * 1000).to_i
      yield(done: true, tokens_in: input_tokens, tokens_out: output_tokens, latency_ms: latency_ms)
    end

    private

    # Rough cost estimates per 1M tokens; update as pricing changes.
    PRICING = {
      'claude-sonnet-4-5' => { in: 3.0, out: 15.0 },
      'claude-opus-4'     => { in: 15.0, out: 75.0 },
      'claude-haiku-4-5'  => { in: 0.8, out: 4.0 },
    }.freeze

    def estimate_cost(model, usage)
      p = PRICING[model] || PRICING.values.first
      ((usage['input_tokens'] || 0) * p[:in] + (usage['output_tokens'] || 0) * p[:out]) / 1_000_000.0
    end
  end
end
