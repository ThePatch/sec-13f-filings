require 'test_helper'

class Ai::RouterTest < ActiveSupport::TestCase
  def setup
    AiProviderConfig.where(session_id: 'sess-1').delete_all
    AiProviderConfig.create!(
      session_id: 'sess-1', provider: 'claude',
      api_key: 'k', last_used_at: nil,
    )

    @router = Ai::Router.new(session_id: 'sess-1')
    @messages = [{ role: 'user', content: 'Why did Berkshire trim Apple?' }]
  end

  test 'message_record emits confidence_tier and parses citations from body' do
    body = <<~HTML
      Berkshire trimmed Apple before Vision Pro inventory cuts [a:42].
      Per the earnings call <span>EPS beat consensus</span> [c:99].
    HTML
    stub_client_for_test(body: body)
    stub_retriever_returning(tier: :high, chunks: [], atoms: [])

    msg = @router.chat(provider: 'claude', model: 'claude-sonnet-4-6', messages: @messages, context: [])

    assert_equal :high, msg[:confidence_tier]
    types = msg[:citations].map { |c| c[:type] }
    assert_includes types, 'atom'
    assert_includes types, 'chunk'
    atom_cite  = msg[:citations].find { |c| c[:type] == 'atom' }
    chunk_cite = msg[:citations].find { |c| c[:type] == 'chunk' }
    assert_equal 42, atom_cite[:id]
    assert_equal 99, chunk_cite[:id]
  end

  test 'system prompt is rendered from system_chat.md with ATOMS and CHUNKS placeholders' do
    captured_prompt = nil
    stub_client_capturing(system_prompt: ->(p) { captured_prompt = p }, body: 'ok')

    fake_chunk = create_dummy_chunk
    fake_atom  = create_dummy_atom

    stub_retriever_returning(tier: :medium, chunks: [fake_chunk.id], atoms: [fake_atom])

    @router.chat(provider: 'claude', model: 'claude-sonnet-4-6', messages: @messages, context: [])

    assert_not_nil captured_prompt
    assert_match(/Citation format/, captured_prompt)
    assert_match(/\[a:#{fake_atom.id}\]/, captured_prompt)
    assert_match(/\[c:#{fake_chunk.id}\]/, captured_prompt)
    assert_no_match(/\{\{ATOMS\}\}/, captured_prompt)
    assert_no_match(/\{\{CHUNKS\}\}/, captured_prompt)
  ensure
    Chunk.where(id: fake_chunk&.id).delete_all if fake_chunk
    Document.where(id: fake_chunk&.document_id).delete_all if fake_chunk
    Atom.where(id: fake_atom&.id).delete_all if fake_atom
  end

  test 'empty atom/chunk results leave blank placeholders' do
    captured_prompt = nil
    stub_client_capturing(system_prompt: ->(p) { captured_prompt = p }, body: 'ok')
    stub_retriever_returning(tier: :none, chunks: [], atoms: [])

    @router.chat(provider: 'claude', model: 'claude-sonnet-4-6', messages: @messages, context: [])

    refute_match(/ATOMS \(compressed memory/, captured_prompt)
    refute_match(/CHUNKS \(raw source/, captured_prompt)
  end

  private

  def stub_client_for_test(body:)
    Ai::AnthropicClient.any_instance.stubs(:chat).returns(
      body: body, tokens_in: 100, tokens_out: 50, cost_usd: 0.001, latency_ms: 500,
    )
  end

  def stub_client_capturing(system_prompt:, body:)
    Ai::AnthropicClient.any_instance
      .stubs(:chat)
      .with { |args| system_prompt.call(args[:system_prompt]); true }
      .returns(body: body, tokens_in: 1, tokens_out: 1, cost_usd: 0.0, latency_ms: 1)
  end

  def stub_retriever_returning(tier:, chunks:, atoms:)
    Retrieval::HybridRetriever.any_instance.stubs(:retrieve).returns(
      Retrieval::HybridRetriever::Result.new(
        atoms: atoms, chunks: chunks, triples: [], tier: tier, diagnostics: {},
      )
    )
  end

  def create_dummy_chunk
    doc = Document.create!(
      doc_type: 'news', source: 'test', source_ref: "router-#{SecureRandom.hex(4)}",
      title: 't', published_at: Time.current,
      content_hash: SecureRandom.hex(8), raw_text: 'x',
    )
    id = ActiveRecord::Base.connection.exec_query(<<~SQL).rows.first.first
      INSERT INTO chunks (document_id, ordinal, text, token_count, start_char, end_char,
                          dense_vec, colbert_blob, colbert_scales, colbert_dim, colbert_tokens)
      VALUES (#{doc.id}, 0, 'sample chunk text', 4, 0, 17,
              '[#{Array.new(96, 0.01).join(',')}]'::vector,
              '\\x00', '\\x00', 96, 4)
      RETURNING id
    SQL
    Chunk.find(id)
  end

  def create_dummy_atom
    chunk = create_dummy_chunk
    Atom.create!(
      chunk_id: chunk.id, document_id: chunk.document_id,
      content: 'sample atom content', content_hash: SecureRandom.hex(8),
      token_count: 50, stability: 1.0,
    )
  end
end
