# NewsAPI's free tier terms prohibit caching raw article content beyond 24h.
# This job nulls raw_text and deletes the linked chunks (which carry the raw
# spans) for any newsapi document older than 24h. Atoms derived from those
# documents are preserved — they're the compressed evidence layer, not the
# source text itself.
module Ingest
  class PurgeNewsApiRawTextJob < ApplicationJob
    queue_as :default

    def perform
      cutoff   = 24.hours.ago
      affected = 0

      Document.where(source: "newsapi")
              .where("ingested_at < ?", cutoff)
              .where.not(raw_text: nil)
              .find_in_batches(batch_size: 200) do |batch|
        batch_ids = batch.map(&:id)
        Chunk.where(document_id: batch_ids).delete_all
        affected += Document.where(id: batch_ids).update_all(
          raw_text: nil,
          metadata: Arel.sql("metadata || '{\"raw_text_purged\": true}'::jsonb"),
        )
      end

      Rails.logger.info("[ingest.purge_newsapi] purged=#{affected}")
      affected
    end
  end
end
