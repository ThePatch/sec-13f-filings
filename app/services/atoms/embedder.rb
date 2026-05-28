# Computes the 384-dim atom embedding used by HybridRetriever for similarity
# scoring. Provider behind MSAM_CONFIG[:atom_embedding_provider]:
#   - "nim"    (default, free) — NVIDIA NIM `nv-embedqa-e5-v5`     (384-dim)
#   - "openai" (paid fallback)  — `text-embedding-3-small`          (1536-dim,
#                                  truncated client-side to 384 to match column)
#
# The atoms.embedding column is `vector(384)`. If the chosen model emits a
# different native dimension, the embedder must truncate or raise a config
# error rather than silently corrupt rows.
require "httparty"

module Atoms
  class Embedder
    DIM = 384  # locked by atoms.embedding column

    def self.embed_batch(texts)
      new.embed_batch(texts)
    end

    def initialize(provider: nil, model: nil)
      @provider = provider || MSAM_CONFIG[:atom_embedding_provider]
      @model    = model    || MSAM_CONFIG[:atom_embedding_model]
    end

    # Returns Array<Array<Float>> aligned with the input texts.
    def embed_batch(texts)
      texts = Array(texts).reject(&:blank?)
      return [] if texts.empty?

      case @provider.to_s
      when "nim"    then embed_via_nim(texts)
      when "openai" then embed_via_openai(texts)
      else raise EmbedderError, "unknown atom_embedding_provider: #{@provider}"
      end
    end

    # Persist embeddings back to atoms.embedding (raw SQL — pgvector 0.2.x
    # has no AR adapter on Ruby 3.0).
    def embed_atoms(atom_ids)
      ids = Array(atom_ids).compact.uniq
      return 0 if ids.empty?

      ids.each_slice(96) do |batch_ids|
        atoms = Atom.where(id: batch_ids).pluck(:id, :content)
        next if atoms.empty?

        vectors = embed_batch(atoms.map(&:last))
        conn = ActiveRecord::Base.connection
        atoms.each_with_index do |(id, _text), i|
          vec = vectors[i]
          next unless vec
          lit = Pgvector.encode(truncate_to_dim(vec))
          conn.execute("UPDATE atoms SET embedding = #{conn.quote(lit)}::vector WHERE id = #{id.to_i}")
        end
      end
      ids.size
    end

    private

    def embed_via_nim(texts)
      api_key = ENV["NIM_API_KEY"]
      raise EmbedderError, "NIM_API_KEY not set" if api_key.blank?

      response = HTTParty.post(
        "https://integrate.api.nvidia.com/v1/embeddings",
        headers: {
          "Authorization" => "Bearer #{api_key}",
          "Content-Type"  => "application/json",
        },
        body: { input: texts, model: @model, input_type: "passage" }.to_json,
        timeout: 30,
      )
      raise EmbedderError, "NIM #{response.code}: #{response.body}" unless response.success?
      response.parsed_response.fetch("data").map { |d| d.fetch("embedding") }
    end

    def embed_via_openai(texts)
      api_key = ENV["OPENAI_API_KEY"]
      raise EmbedderError, "OPENAI_API_KEY not set" if api_key.blank?

      response = HTTParty.post(
        "https://api.openai.com/v1/embeddings",
        headers: {
          "Authorization" => "Bearer #{api_key}",
          "Content-Type"  => "application/json",
        },
        body: { input: texts, model: @model }.to_json,
        timeout: 30,
      )
      raise EmbedderError, "OpenAI #{response.code}: #{response.body}" unless response.success?
      response.parsed_response.fetch("data").map { |d| d.fetch("embedding") }
    end

    # If the model emits more than DIM dims, take the first DIM (Matryoshka-style).
    # If it emits fewer, raise — we don't pad.
    def truncate_to_dim(vec)
      return vec if vec.length == DIM
      raise EmbedderError, "embedding dim #{vec.length} < #{DIM}; check model config" if vec.length < DIM
      vec.first(DIM)
    end
  end
end
