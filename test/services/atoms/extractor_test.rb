require 'test_helper'

module Atoms
  class ExtractorTest < ActiveSupport::TestCase
    def setup
      ENV["ANTHROPIC_API_KEY"] ||= "test-key-#{SecureRandom.hex(4)}"
      @company = Company.create!(cusip: SecureRandom.hex(4).upcase.ljust(9, '0').slice(0, 9), name: "Apple Inc.", ticker: "AAPL")
      @doc = Document.create!(
        company_id: @company.id, doc_type: "news", source: "test",
        source_ref: "ext-#{SecureRandom.hex(4)}", title: "earnings",
        published_at: Time.current, content_hash: SecureRandom.hex(8),
        raw_text: "x",
      )
      @chunk_id = ActiveRecord::Base.connection.exec_query(<<~SQL).rows.first.first
        INSERT INTO chunks (document_id, ordinal, text, token_count, start_char, end_char,
                            dense_vec, colbert_blob, colbert_scales, colbert_dim, colbert_tokens)
        VALUES (#{@doc.id}, 0, 'Apple beat EPS in Q3 2025.', 7, 0, 24,
                '[#{Array.new(96, 0.01).join(',')}]'::vector,
                '\\x00', '\\x00', 96, 7)
        RETURNING id
      SQL
      @chunk = Chunk.find(@chunk_id)
    end

    def teardown
      Atom.where(chunk_id: @chunk_id).delete_all
      Chunk.where(id: @chunk_id).delete_all
      Document.where(id: @doc.id).delete_all
      Company.where(id: @company.id).delete_all
    end

    test 'extracts atoms from chunk and persists with hashing' do
      stub_llm_returning_json({
        atoms: [
          { content: "Apple beat EPS estimates in Q3 2025.", profile: "lightweight",
            topics: ["AAPL", "earnings"], arousal: 0.3, valence: 0.6,
            source_quote: "Apple beat EPS in Q3 2025." },
        ],
      })
      ids = Atoms::Extractor.new.extract(chunk: @chunk)
      assert_equal 1, ids.size

      atom = Atom.find(ids.first)
      assert_equal "lightweight", atom.profile
      assert_equal @company.id, atom.company_id
      assert_includes atom.topics, "AAPL"
    end

    test 'idempotent: extracting twice does not create duplicate atoms' do
      payload = { atoms: [{ content: "Identical content", source_quote: "x" }] }
      stub_llm_returning_json(payload)
      ids1 = Atoms::Extractor.new.extract(chunk: @chunk)
      ids2 = Atoms::Extractor.new.extract(chunk: @chunk)
      assert_equal ids1, ids2
      assert_equal 1, Atom.where(chunk_id: @chunk_id).count
    end

    test 'invalid JSON retries once then raises ExtractionError' do
      Ai::AnthropicClient.any_instance.stubs(:chat).returns(
        { body: "not json", tokens_in: 1, tokens_out: 1, latency_ms: 1 }
      )
      assert_raises(Atoms::ExtractionError) do
        Atoms::Extractor.new.extract(chunk: @chunk)
      end
    end

    test 'returns no atoms when LLM emits empty array' do
      stub_llm_returning_json({ atoms: [] })
      ids = Atoms::Extractor.new.extract(chunk: @chunk)
      assert_empty ids
    end

    private

    def stub_llm_returning_json(payload)
      Ai::AnthropicClient.any_instance.stubs(:chat).returns(
        body: payload.to_json,
        tokens_in: 100, tokens_out: 50, cost_usd: 0.001, latency_ms: 200,
      )
    end
  end
end
