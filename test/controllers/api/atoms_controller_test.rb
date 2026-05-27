require 'test_helper'

module Api
  class AtomsControllerTest < ActionDispatch::IntegrationTest
    def setup
      @doc = Document.create!(
        doc_type: 'news', source: 'test', source_ref: "atomctrl-#{SecureRandom.hex(4)}",
        title: 'doc', published_at: Time.current,
        content_hash: SecureRandom.hex(8), raw_text: 'x',
      )
      @chunk_id = ActiveRecord::Base.connection.exec_query(<<~SQL).rows.first.first
        INSERT INTO chunks (document_id, ordinal, text, token_count, start_char, end_char,
                            dense_vec, colbert_blob, colbert_scales, colbert_dim, colbert_tokens)
        VALUES (#{@doc.id}, 0, 'source chunk text', 3, 0, 17,
                '[#{Array.new(96, 0.01).join(',')}]'::vector,
                '\\x00', '\\x00', 96, 3)
        RETURNING id
      SQL
      @atom = Atom.create!(
        chunk_id: @chunk_id, document_id: @doc.id,
        content: 'Apple beat EPS in Q3 2025',
        source_quote: '"Apple beat EPS estimates"',
        content_hash: SecureRandom.hex(8), token_count: 50, stability: 1.0,
        topics: %w[apple earnings],
      )
    end

    def teardown
      Atom.where(id: @atom.id).delete_all
      Chunk.where(id: @chunk_id).delete_all
      Document.where(id: @doc.id).delete_all
    end

    test '/api/atoms/:id returns content + source linkage' do
      get "/api/atoms/#{@atom.id}"
      assert_response :success
      body = JSON.parse(response.body)
      assert_equal @atom.id, body['id']
      assert_equal 'Apple beat EPS in Q3 2025', body['content']
      assert_equal @chunk_id, body['chunk']['id']
      assert_equal @doc.id, body['document']['id']
      assert_includes body['topics'], 'apple'
    end

    test '/api/atoms/:id 404s on unknown id' do
      get '/api/atoms/9999999'
      assert_response :not_found
    end
  end
end
