require 'test_helper'

module Atoms
  class TripleExtractorTest < ActiveSupport::TestCase
    def setup
      ENV["ANTHROPIC_API_KEY"] ||= "test-#{SecureRandom.hex(4)}"
      @doc = Document.create!(
        doc_type: "news", source: "test", source_ref: "te-#{SecureRandom.hex(4)}",
        title: "x", published_at: Time.current,
        content_hash: SecureRandom.hex(8), raw_text: "x",
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
      @atom = Atom.create!(
        chunk_id: @chunk_id, document_id: @doc.id,
        content: "Apple beat EPS.", content_hash: SecureRandom.hex(8),
        token_count: 10, stability: 1.0, encoding_confidence: 0.9,
      )
    end

    def teardown
      Triple.where(source_atom_id: @atom.id).delete_all
      Triple.where(subject: "Apple Inc.").delete_all
      Atom.where(id: @atom.id).delete_all
      Chunk.where(id: @chunk_id).delete_all
      Document.where(id: @doc.id).delete_all
    end

    test 'persists triples linked to highest-confidence atom' do
      stub_llm_returning_json({
        triples: [
          { subject: "Apple Inc.", predicate: "beat_eps", object: "Q3 2025", confidence: 0.95 },
        ],
      })
      ids = Atoms::TripleExtractor.new.extract(chunk: @chunk, atom_ids: [@atom.id])
      assert_equal 1, ids.size

      t = Triple.find(ids.first)
      assert_equal @atom.id, t.source_atom_id
      assert_in_delta 0.95, t.confidence, 1e-6
      assert_nil t.valid_until
    end

    test 'updating an existing fact auto-closes the prior triple' do
      Triple.create!(subject: "Apple Inc.", predicate: "ceo", object: "Steve Jobs",
                     confidence: 1.0, valid_from: 1.year.ago, source_atom_id: @atom.id)
      stub_llm_returning_json({
        triples: [{ subject: "Apple Inc.", predicate: "ceo", object: "Tim Cook", confidence: 0.99 }],
      })

      Atoms::TripleExtractor.new.extract(chunk: @chunk, atom_ids: [@atom.id])

      closed = Triple.where(subject: "Apple Inc.", predicate: "ceo", object: "Steve Jobs").first
      current = Triple.where(subject: "Apple Inc.", predicate: "ceo", object: "Tim Cook").first

      assert_not_nil closed.valid_until, "old triple should be auto-closed"
      assert_nil current.valid_until, "new triple should be currently valid"
    end

    private

    def stub_llm_returning_json(payload)
      Ai::AnthropicClient.any_instance.stubs(:chat).returns(
        body: payload.to_json, tokens_in: 1, tokens_out: 1, latency_ms: 1,
      )
    end
  end
end
