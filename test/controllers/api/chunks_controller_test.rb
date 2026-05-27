require 'test_helper'

module Api
  class ChunksControllerTest < ActionDispatch::IntegrationTest
    def setup
      @doc = Document.create!(
        doc_type: 'news', source: 'test', source_ref: "ctrl-#{SecureRandom.hex(4)}",
        title: 'Apple earnings recap', published_at: Time.current,
        content_hash: SecureRandom.hex(8), raw_text: 'x',
      )
      @chunk_id = ActiveRecord::Base.connection.exec_query(<<~SQL).rows.first.first
        INSERT INTO chunks (document_id, ordinal, text, token_count, start_char, end_char,
                            dense_vec, colbert_blob, colbert_scales, colbert_dim, colbert_tokens)
        VALUES (#{@doc.id}, 0, 'Apple reported $89.5B revenue', 5, 0, 28,
                '[#{Array.new(96, 0.01).join(',')}]'::vector,
                '\\x00', '\\x00', 96, 5)
        RETURNING id
      SQL
    end

    def teardown
      Chunk.where(id: @chunk_id).delete_all
      Document.where(id: @doc.id).delete_all
    end

    test '/api/chunks/:id returns the chunk text + document metadata' do
      get "/api/chunks/#{@chunk_id}"
      assert_response :success
      body = JSON.parse(response.body)
      assert_equal @chunk_id, body['id']
      assert_equal 'Apple reported $89.5B revenue', body['text']
      assert_equal 'news', body['document']['doc_type']
      assert_equal 'Apple earnings recap', body['document']['title']
    end

    test '/api/chunks/:id 404s on unknown id' do
      get '/api/chunks/9999999'
      assert_response :not_found
    end
  end
end
