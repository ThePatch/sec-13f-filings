module Atoms
  class EmbedJob < ApplicationJob
    queue_as :default

    def perform(atom_ids)
      ids = Array(atom_ids).compact.uniq
      return if ids.empty?
      Atoms::Embedder.new.embed_atoms(ids)
    rescue Atoms::EmbedderError => e
      Rails.logger.warn("[atoms.embed_job] skipped #{ids.size} atoms: #{e.message}")
      # Re-enqueue is intentionally NOT here — embed failures are usually
      # config (missing API key) and we don't want a retry loop.
    end
  end
end
