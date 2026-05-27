require 'test_helper'
require 'webmock/minitest'

class ColbertClientTest < ActiveSupport::TestCase
  BASE = 'http://127.0.0.1:7400'.freeze

  def setup
    WebMock.disable_net_connect!
  end

  def teardown
    WebMock.reset!
    WebMock.allow_net_connect!
  end

  test 'health returns parsed JSON' do
    stub_request(:get, "#{BASE}/health").to_return(
      status: 200,
      body: { ok: true, model: 'answerdotai/answerai-colbert-small-v1', dim: 96 }.to_json,
      headers: { 'Content-Type' => 'application/json' },
    )

    result = ColbertClient.health
    assert_equal true, result['ok']
    assert_equal 96, result['dim']
  end

  test 'embed_chunk unwraps the response into the documented shape' do
    stub_request(:post, "#{BASE}/embed_chunk")
      .with(body: { text: 'Apple beat EPS.' }.to_json)
      .to_return(
        status: 200,
        body: {
          dense_vec: Array.new(96, 0.1),
          colbert_blob_b64: 'AAAA',
          colbert_scales_b64: 'BBBB',
          colbert_dim: 96,
          colbert_tokens: 5,
          encode_ms: 42.0,
        }.to_json,
        headers: { 'Content-Type' => 'application/json' },
      )

    result = ColbertClient.embed_chunk(text: 'Apple beat EPS.')
    assert_equal 96, result[:dense_vec].length
    assert_equal 'AAAA', result[:colbert_blob_b64]
    assert_equal 'BBBB', result[:colbert_scales_b64]
    assert_equal 96, result[:colbert_dim]
    assert_equal 5, result[:token_count]
  end

  test 'score orders results desc by score' do
    stub_request(:post, "#{BASE}/score").to_return(
      status: 200,
      body: {
        results: [
          { chunk_id: 7, score: 3.4 },
          { chunk_id: 9, score: 2.1 },
        ],
        query_tokens: 4,
        score_ms: 50.0,
      }.to_json,
      headers: { 'Content-Type' => 'application/json' },
    )

    result = ColbertClient.score(
      query: 'Apple',
      candidates: [{ id: 7, blob_b64: 'x', scales_b64: 'y', dim: 96, num_tokens: 5 }],
      top_k: 2,
    )

    assert_equal 7, result[:results].first[:chunk_id]
    assert_in_delta 3.4, result[:results].first[:score], 1e-6
  end

  test 'raises ColbertClient::Error on non-2xx response' do
    stub_request(:post, "#{BASE}/embed_chunk").to_return(status: 503, body: 'model not loaded')

    err = assert_raises(ColbertClient::Error) do
      ColbertClient.embed_chunk(text: 'x')
    end
    assert_match(/503/, err.message)
  end

  test 'raises ColbertClient::Error on connection refused' do
    stub_request(:post, "#{BASE}/embed_chunk").to_raise(Errno::ECONNREFUSED)

    err = assert_raises(ColbertClient::Error) do
      ColbertClient.embed_chunk(text: 'x')
    end
    assert_match(/unreachable/, err.message)
  end
end
