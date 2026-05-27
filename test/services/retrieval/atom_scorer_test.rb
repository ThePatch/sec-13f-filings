require 'test_helper'

class Retrieval::AtomScorerTest < ActiveSupport::TestCase
  def setup
    @doc = Document.create!(
      doc_type: 'news', source: 'test', source_ref: "scorer-#{SecureRandom.hex(4)}",
      title: 't', published_at: Time.current,
      content_hash: SecureRandom.hex(8), raw_text: 'x',
    )
    @chunk_id = ActiveRecord::Base.connection.exec_query(<<~SQL).rows.first.first
      INSERT INTO chunks (document_id, ordinal, text, token_count, start_char, end_char,
                          dense_vec, colbert_blob, colbert_scales, colbert_dim, colbert_tokens)
      VALUES (#{@doc.id}, 0, 'x', 1, 0, 1, '[#{Array.new(96, 0.01).join(',')}]'::vector,
              '\\x00', '\\x00', 96, 1)
      RETURNING id
    SQL
  end

  def teardown
    AtomOutcome.where(atom_id: Atom.where(chunk_id: @chunk_id).pluck(:id)).delete_all
    Atom.where(chunk_id: @chunk_id).delete_all
    Chunk.where(id: @chunk_id).delete_all
    Document.where(id: @doc.id).delete_all
  end

  test 'returns empty array when no atoms exist' do
    scorer = Retrieval::AtomScorer.new(query: 'q')
    assert_empty scorer.activate_for(chunk_ids: [@chunk_id], tier: :high)
  end

  test 'activation formula matches hand-computed value (no similarity)' do
    a = make_atom(access_count: 0, stability: 1.0)
    scorer = Retrieval::AtomScorer.new(query: 'q')  # no query_embedding → similarity = 0

    # base = ln(0+1) * 0.5 = 0
    # recency, outcome = 0 (no last_accessed, no outcomes)
    # activation = 0 * stability = 0
    assert_in_delta 0.0, scorer.activation(a), 1e-6
  end

  test 'activation positive when access_count > 0' do
    a = make_atom(access_count: 7, stability: 1.0)
    scorer = Retrieval::AtomScorer.new(query: 'q')
    # base = ln(8) * 0.5 = 1.0397
    assert_in_delta Math.log(8) * 0.5, scorer.activation(a), 1e-4
  end

  test 'stability scales activation linearly' do
    a = make_atom(access_count: 7, stability: 2.0)
    scorer = Retrieval::AtomScorer.new(query: 'q')
    assert_in_delta Math.log(8) * 0.5 * 2.0, scorer.activation(a), 1e-4
  end

  test 'record_retrieval increments access_count and stamps last_accessed_at' do
    a = make_atom(access_count: 5, stability: 1.0)
    t0 = a.last_accessed_at
    Retrieval::AtomScorer.record_retrieval([a.id], session_id: 'test')
    a.reload
    assert_equal 6, a.access_count
    assert_not_nil a.last_accessed_at
    assert_operator a.last_accessed_at, :!=, t0
  end

  test 'record_retrieval inserts pairwise co_retrievals respecting atom_a < atom_b' do
    a1 = make_atom(access_count: 0, stability: 1.0)
    a2 = make_atom(access_count: 0, stability: 1.0)
    a3 = make_atom(access_count: 0, stability: 1.0)
    Retrieval::AtomScorer.record_retrieval([a1.id, a2.id, a3.id], session_id: 'test')
    rows = ActiveRecord::Base.connection.select_all(
      "SELECT atom_a, atom_b, count FROM atom_co_retrievals WHERE atom_a IN (#{[a1.id, a2.id, a3.id].join(',')}) OR atom_b IN (#{[a1.id, a2.id, a3.id].join(',')})"
    ).to_a
    assert_equal 3, rows.size  # C(3,2) = 3 pairs
    rows.each { |r| assert_operator r['atom_a'], :<, r['atom_b'] }
  ensure
    ActiveRecord::Base.connection.execute("DELETE FROM atom_co_retrievals WHERE atom_a IN (#{[a1, a2, a3].compact.map(&:id).join(',')}) OR atom_b IN (#{[a1, a2, a3].compact.map(&:id).join(',')})") if a1 && a2 && a3
  end

  test 'duplicate co_retrieval increments count' do
    a1 = make_atom(access_count: 0, stability: 1.0)
    a2 = make_atom(access_count: 0, stability: 1.0)
    2.times { Retrieval::AtomScorer.record_retrieval([a1.id, a2.id], session_id: 'test') }
    row = ActiveRecord::Base.connection.select_one(
      "SELECT count FROM atom_co_retrievals WHERE atom_a = #{[a1.id, a2.id].min} AND atom_b = #{[a1.id, a2.id].max}"
    )
    assert_equal 2, row['count']
  ensure
    ActiveRecord::Base.connection.execute("DELETE FROM atom_co_retrievals WHERE atom_a IN (#{[a1, a2].compact.map(&:id).join(',')}) OR atom_b IN (#{[a1, a2].compact.map(&:id).join(',')})") if a1 && a2
  end

  private

  def make_atom(access_count:, stability:, last_accessed_at: nil)
    Atom.create!(
      chunk_id:     @chunk_id,
      document_id:  @doc.id,
      content:      "atom #{SecureRandom.hex(4)}",
      content_hash: SecureRandom.hex(8),
      token_count:  50,
      access_count: access_count,
      stability:    stability,
      last_accessed_at: last_accessed_at,
    )
  end
end
