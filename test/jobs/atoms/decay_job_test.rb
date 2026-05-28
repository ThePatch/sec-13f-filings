require 'test_helper'

module Atoms
  class DecayJobTest < ActiveSupport::TestCase
    def setup
      @doc = Document.create!(
        doc_type: "news", source: "test", source_ref: "decay-#{SecureRandom.hex(4)}",
        title: "x", published_at: Time.current,
        content_hash: SecureRandom.hex(8), raw_text: "x",
      )
      @chunk_id = ActiveRecord::Base.connection.exec_query(<<~SQL).rows.first.first
        INSERT INTO chunks (document_id, ordinal, text, token_count, start_char, end_char,
                            dense_vec, colbert_blob, colbert_scales, colbert_dim, colbert_tokens)
        VALUES (#{@doc.id}, 0, 'x', 1, 0, 1,
                '[#{Array.new(96, 0.01).join(',')}]'::vector,
                '\\x00', '\\x00', 96, 1)
        RETURNING id
      SQL
    end

    def teardown
      Atom.where(chunk_id: @chunk_id).delete_all
      Chunk.where(id: @chunk_id).delete_all
      Document.where(id: @doc.id).delete_all
    end

    test 'active atom unaccessed for 30 days transitions to fading' do
      atom = make_atom(state: "active", last_accessed_at: 30.days.ago, stability: 1.0)
      # Skip compaction by leaving ENV unset
      ENV.delete("ANTHROPIC_API_KEY")
      Atoms::DecayJob.new.perform
      atom.reload
      assert_equal "fading", atom.state
      assert_operator atom.retrievability, :<, Atoms::DecayJob::R_TO_FADING
    end

    test 'fading atom further decayed transitions to dormant' do
      atom = make_atom(state: "fading", last_accessed_at: 90.days.ago, stability: 1.0)
      ENV.delete("ANTHROPIC_API_KEY")
      Atoms::DecayJob.new.perform
      atom.reload
      assert_equal "dormant", atom.state
    end

    test 'pinned atom is exempt from decay' do
      atom = make_atom(state: "active", last_accessed_at: 365.days.ago, stability: 1.0, is_pinned: true)
      Atoms::DecayJob.new.perform
      atom.reload
      assert_equal "active", atom.state
    end

    test 'fresh atom stays active' do
      atom = make_atom(state: "active", last_accessed_at: 1.hour.ago, stability: 1.0)
      Atoms::DecayJob.new.perform
      atom.reload
      assert_equal "active", atom.state
    end

    private

    def make_atom(state:, last_accessed_at:, stability:, is_pinned: false)
      Atom.create!(
        chunk_id: @chunk_id, document_id: @doc.id,
        content: "decay #{SecureRandom.hex(4)}",
        content_hash: SecureRandom.hex(8), token_count: 10,
        state: state, last_accessed_at: last_accessed_at,
        stability: stability, is_pinned: is_pinned, profile: "lightweight",
      )
    end
  end
end
