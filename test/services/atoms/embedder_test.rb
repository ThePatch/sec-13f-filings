require 'test_helper'
require 'webmock/minitest'

module Atoms
  class EmbedderTest < ActiveSupport::TestCase
    def setup
      WebMock.disable_net_connect!(allow_localhost: true)
      @prev_nim = ENV["NIM_API_KEY"]
      ENV["NIM_API_KEY"] = "test-nim"
    end

    def teardown
      WebMock.reset!
      WebMock.allow_net_connect!
      ENV["NIM_API_KEY"] = @prev_nim
    end

    test 'embed_batch returns vectors aligned with inputs' do
      stub_nim_returning([
        Array.new(384, 0.1),
        Array.new(384, 0.2),
      ])

      vectors = Atoms::Embedder.new(provider: "nim").embed_batch(["a", "b"])
      assert_equal 2, vectors.size
      assert_equal 384, vectors.first.size
      assert_in_delta 0.1, vectors.first.first, 1e-6
      assert_in_delta 0.2, vectors.last.first, 1e-6
    end

    test 'embed_batch with empty input returns []' do
      assert_empty Atoms::Embedder.new(provider: "nim").embed_batch([])
    end

    test 'raises when model emits wrong dim during persist' do
      doc = Document.create!(
        doc_type: "news", source: "test", source_ref: "embdim-#{SecureRandom.hex(4)}",
        title: "x", published_at: Time.current,
        content_hash: SecureRandom.hex(8), raw_text: "x",
      )
      atom = Atom.create!(
        document_id: doc.id, content: "x #{SecureRandom.hex(4)}",
        content_hash: SecureRandom.hex(8), token_count: 1, stability: 1.0,
      )
      stub_nim_returning([Array.new(100, 0.1)])  # wrong dim: 100 instead of 384

      assert_raises(Atoms::EmbedderError) do
        Atoms::Embedder.new(provider: "nim").embed_atoms([atom.id])
      end
    ensure
      Atom.where(id: atom&.id).delete_all if atom
      Document.where(id: doc&.id).delete_all if doc
    end

    test 'embed_atoms persists vectors to atoms.embedding via raw SQL' do
      doc = Document.create!(
        doc_type: "news", source: "test", source_ref: "emb-#{SecureRandom.hex(4)}",
        title: "x", published_at: Time.current,
        content_hash: SecureRandom.hex(8), raw_text: "x",
      )
      atom = Atom.create!(
        document_id: doc.id, content: "test embed", content_hash: SecureRandom.hex(8),
        token_count: 5, stability: 1.0,
      )
      stub_nim_returning([Array.new(384, 0.5)])

      count = Atoms::Embedder.new(provider: "nim").embed_atoms([atom.id])
      assert_equal 1, count

      stored = ActiveRecord::Base.connection.select_value(
        "SELECT embedding::text FROM atoms WHERE id = #{atom.id}"
      )
      assert_match(/\A\[0\.5/, stored)
    ensure
      Atom.where(id: atom&.id).delete_all if atom
      Document.where(id: doc&.id).delete_all if doc
    end

    private

    def stub_nim_returning(vectors)
      body = { data: vectors.map { |v| { embedding: v } } }.to_json
      stub_request(:post, "https://integrate.api.nvidia.com/v1/embeddings")
        .to_return(status: 200, body: body, headers: { "Content-Type" => "application/json" })
    end
  end
end
