# End-to-end pipeline: raw doc → chunks (ColBERT-embedded) → atoms (LLM) →
# triples (LLM). Idempotent — skips already-processed docs. Atom extraction
# errors don't roll back chunk persistence (chunks are still retrievable
# without their atoms).
require "base64"

class ProcessDocumentJob < ApplicationJob
  queue_as :default

  def perform(document_id)
    doc = Document.find_by(id: document_id)
    return unless doc
    return if doc.processed_at
    return if doc.raw_text.blank?

    instrument(doc) do
      chunks_data = chunker_for(doc.doc_type).new(doc.raw_text).chunks
      Rails.logger.info("[process_document] doc=#{doc.id} chunks=#{chunks_data.size}")

      chunks_data.each_with_index do |chunk_data, ordinal|
        chunk = persist_chunk(doc, chunk_data, ordinal)
        next unless chunk

        # Atom + triple extraction are per-chunk and individually rescued —
        # one bad chunk shouldn't kill the rest of the document.
        begin
          atom_ids = Atoms::Extractor.new.extract(chunk: chunk)
          Atoms::EmbedJob.perform_later(atom_ids) if atom_ids.any?
          Atoms::TripleExtractor.new.extract(chunk: chunk, atom_ids: atom_ids) if atom_ids.any?
        rescue Atoms::ExtractionError, Atoms::TripleExtractionError => e
          Rails.logger.warn("[process_document] atoms failed doc=#{doc.id} chunk=#{chunk.id}: #{e.message}")
        rescue => e
          Rails.logger.error("[process_document] unexpected doc=#{doc.id} chunk=#{chunk.id}: #{e.class}: #{e.message}")
        end
      end

      doc.update!(processed_at: Time.current)
    end
  end

  private

  def instrument(doc)
    ActiveSupport::Notifications.instrument(
      "ingest.process_document", document_id: doc.id, doc_type: doc.doc_type,
    ) { yield }
  end

  def chunker_for(doc_type)
    # Phase 10 (T-536) introduces per-doc-type chunkers — earnings (speaker-
    # aware), news (paragraph), SEC (item boundary), letter (paragraph).
    # Until then, every doc_type falls through to the paragraph fallback.
    Chunkers::Fallback
  end

  def persist_chunk(doc, c, ordinal)
    embed = ColbertClient.embed_chunk(text: c[:text])
    conn  = ActiveRecord::Base.connection

    dense_lit  = Pgvector.encode(embed[:dense_vec])
    blob_hex   = Base64.decode64(embed[:colbert_blob_b64]).unpack1("H*")
    scales_hex = Base64.decode64(embed[:colbert_scales_b64]).unpack1("H*")

    sql = <<~SQL
      INSERT INTO chunks (
        document_id, ordinal, text, token_count, start_char, end_char,
        speaker, section,
        dense_vec, colbert_blob, colbert_scales, colbert_dim, colbert_tokens
      ) VALUES (
        #{doc.id.to_i},
        #{ordinal.to_i},
        #{conn.quote(c[:text])},
        #{c[:token_count].to_i},
        #{c[:start_char].to_i},
        #{c[:end_char].to_i},
        #{c[:speaker] ? conn.quote(c[:speaker]) : 'NULL'},
        #{c[:section] ? conn.quote(c[:section]) : 'NULL'},
        #{conn.quote(dense_lit)}::vector,
        decode(#{conn.quote(blob_hex)}, 'hex'),
        decode(#{conn.quote(scales_hex)}, 'hex'),
        #{embed[:colbert_dim].to_i},
        #{embed[:token_count].to_i}
      )
      ON CONFLICT (document_id, ordinal) DO NOTHING
      RETURNING id
    SQL
    row = conn.exec_query(sql, "process_document.chunk").rows.first
    return Chunk.find_by(document_id: doc.id, ordinal: ordinal) unless row
    Chunk.find(row.first)
  rescue ColbertClient::Error => e
    Rails.logger.error("[process_document] ColBERT failed doc=#{doc.id} ord=#{ordinal}: #{e.message}")
    nil
  end
end
