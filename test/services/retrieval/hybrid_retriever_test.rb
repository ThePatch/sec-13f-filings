require 'test_helper'
require 'webmock/minitest'

class Retrieval::HybridRetrieverTest < ActiveSupport::TestCase
  BASE = 'http://127.0.0.1:7400'.freeze

  def setup
    WebMock.disable_net_connect!(allow_localhost: false)
    @doc = Document.create!(
      doc_type: 'news', source: 'test', source_ref: "ret-#{SecureRandom.hex(4)}",
      title: 't', published_at: Time.current,
      content_hash: SecureRandom.hex(8), raw_text: 'x',
    )
    @chunk_ids = 3.times.map do |i|
      insert_chunk(@doc.id, i, "Sample chunk #{i}")
    end
  end

  def teardown
    Chunk.where(document_id: @doc.id).delete_all
    Document.where(id: @doc.id).delete_all
    WebMock.reset!
    WebMock.allow_net_connect!
  end

  test 'returns :none when query is blank' do
    result = Retrieval::HybridRetriever.new(query: '').retrieve
    assert_equal :none, result.tier
    assert_empty result.chunks
  end

  test 'returns :none when sidecar returns zero candidates' do
    stub_encode_query(query_tokens: 4)
    stub_score(scored: [])
    # pgvector_first_pass still returns chunk ids, but stubbed /score returns empty
    result = Retrieval::HybridRetriever.new(query: 'unrelated thing').retrieve
    assert_equal :none, result.tier
  end

  test 'top score above 0.62/qtok lands :high tier' do
    stub_encode_query(query_tokens: 4)
    stub_score(scored: [
      { chunk_id: @chunk_ids[0], score: 3.5 }, # 0.875 per qtok → high
      { chunk_id: @chunk_ids[1], score: 2.0 },
    ])
    result = Retrieval::HybridRetriever.new(query: 'q').retrieve
    assert_equal :high, result.tier
    assert_equal @chunk_ids[0], result.chunks.first
  end

  test 'top score 0.45..0.62 lands :medium tier' do
    stub_encode_query(query_tokens: 4)
    stub_score(scored: [
      { chunk_id: @chunk_ids[0], score: 2.0 }, # 0.5 per qtok → medium
    ])
    result = Retrieval::HybridRetriever.new(query: 'q').retrieve
    assert_equal :medium, result.tier
    assert_operator result.chunks.size, :<=, 3
  end

  test 'top score 0.30..0.45 lands :low tier and emits no chunks' do
    stub_encode_query(query_tokens: 4)
    stub_score(scored: [
      { chunk_id: @chunk_ids[0], score: 1.4 }, # 0.35 per qtok → low
    ])
    result = Retrieval::HybridRetriever.new(query: 'q').retrieve
    assert_equal :low, result.tier
    assert_empty result.chunks
  end

  test 'top score below 0.30 lands :none' do
    stub_encode_query(query_tokens: 4)
    stub_score(scored: [
      { chunk_id: @chunk_ids[0], score: 0.5 }, # 0.125 per qtok → none
    ])
    result = Retrieval::HybridRetriever.new(query: 'q').retrieve
    assert_equal :none, result.tier
  end

  test 'falls through to :none when sidecar is unreachable' do
    stub_request(:post, "#{BASE}/encode_query").to_raise(Errno::ECONNREFUSED)
    result = Retrieval::HybridRetriever.new(query: 'q').retrieve
    assert_equal :none, result.tier
  end

  private

  def stub_encode_query(query_tokens:)
    stub_request(:post, "#{BASE}/encode_query").to_return(
      status: 200,
      body: { dense_vec: Array.new(96, 0.01), query_tokens: query_tokens }.to_json,
      headers: { 'Content-Type' => 'application/json' },
    )
  end

  def stub_score(scored:)
    stub_request(:post, "#{BASE}/score").to_return(
      status: 200,
      body: { results: scored, query_tokens: 4, score_ms: 50 }.to_json,
      headers: { 'Content-Type' => 'application/json' },
    )
  end

  def insert_chunk(doc_id, ordinal, text)
    conn = ActiveRecord::Base.connection
    dense_lit = Pgvector.encode(Array.new(96, 0.01))
    sql = <<~SQL
      INSERT INTO chunks (document_id, ordinal, text, token_count, start_char, end_char,
                          dense_vec, colbert_blob, colbert_scales, colbert_dim, colbert_tokens)
      VALUES (#{doc_id}, #{ordinal}, #{conn.quote(text)}, 5, 0, #{text.length},
              #{conn.quote(dense_lit)}::vector,
              '\\x00', '\\x00', 96, 5)
      RETURNING id
    SQL
    conn.exec_query(sql).rows.first.first
  end
end
