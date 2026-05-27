# Orchestrates dense first-pass + ColBERT MaxSim re-rank + MSAM atom retrieval.
# Returns a confidence-tiered Result the LLM router folds into the system prompt.
#
# Read handoff/v2/02_ARCHITECTURE.md before changing.
module Retrieval
  class HybridRetriever
    Result = Struct.new(:atoms, :chunks, :triples, :tier, :diagnostics, keyword_init: true)

    def initialize(query:, context_refs: [], session_id: nil, top_k: nil)
      @query        = query.to_s
      @context_refs = Array(context_refs)
      @session_id   = session_id
      @top_k        = top_k || MSAM_CONFIG[:default_top_k]
      @diag         = { started_at: Time.current }
    end

    def retrieve
      return empty(:none) if @query.strip.empty?

      # 1. Encode query through the sidecar
      q = ColbertClient.encode_query(text: @query)
      query_dense = q.fetch("dense_vec")
      query_tokens = q.fetch("query_tokens").to_i.clamp(1, 100)
      @diag[:query_tokens] = query_tokens

      # 2. Dense first-pass
      candidate_ids = pgvector_first_pass(query_dense)
      @diag[:dense_count] = candidate_ids.size
      return empty(:none) if candidate_ids.empty?

      # 3. ColBERT MaxSim re-rank
      candidates = load_candidates(candidate_ids)
      return empty(:none) if candidates.empty?

      scored = ColbertClient.score(
        query: @query,
        candidates: candidates,
        top_k: MSAM_CONFIG[:colbert_top_k],
      ).fetch(:results)
      @diag[:rerank_count] = scored.size
      return empty(:none) if scored.empty?

      # 4. Confidence tier (per query-token max-sim score)
      top_per_qtok = scored.first[:score] / query_tokens.to_f
      tier = tier_for(top_per_qtok)
      @diag[:top_score_per_qtok] = top_per_qtok.round(4)
      @diag[:tier] = tier

      # 5. Atoms (best-effort — empty until T-520+ creates them)
      top_chunk_ids = scored.first(@top_k).map { |s| s[:chunk_id] }
      atoms = activate_atoms_for(top_chunk_ids, tier: tier)
      AtomScorer.record_retrieval(atoms.map(&:id), session_id: @session_id) if atoms.any?

      # 6. Triples (high-tier only)
      triples = (tier == :high) ? current_triples_for(top_chunk_ids) : []

      apply_gating(top_chunk_ids, atoms, triples, tier)
    rescue ColbertClient::Error => e
      Rails.logger.warn("[retrieval] colbert error: #{e.message}")
      empty(:none)
    ensure
      @diag[:elapsed_ms] = ((Time.current - @diag[:started_at]) * 1000).round
      Rails.logger.info("[retrieval] #{@diag.inspect}")
    end

    private

    def pgvector_first_pass(dense_vec)
      vec_literal = Pgvector.encode(dense_vec)
      conn = ActiveRecord::Base.connection
      vec_quoted = conn.quote(vec_literal)

      sql = +"SELECT chunks.id FROM chunks"
      params = {}
      if (cref = @context_refs.find { |r| (r[:ref_type] || r['ref_type']).to_s == 'company' })
        sql << " JOIN documents ON documents.id = chunks.document_id"
        sql << " WHERE documents.company_id = #{conn.quote(cref[:ref_id] || cref['ref_id'])}"
      end
      sql << " ORDER BY chunks.dense_vec <=> #{vec_quoted}::vector"
      sql << " LIMIT #{MSAM_CONFIG[:pgvector_top_k]}"

      conn.exec_query(sql, "pgvector_first_pass").rows.flatten
    end

    def load_candidates(chunk_ids)
      Chunk.where(id: chunk_ids)
           .pluck(:id, :colbert_blob, :colbert_scales, :colbert_dim, :colbert_tokens)
           .map do |id, blob, scales, dim, num_tokens|
        {
          id:         id,
          blob_b64:   Base64.strict_encode64(blob.to_s),
          scales_b64: Base64.strict_encode64(scales.to_s),
          dim:        dim,
          num_tokens: num_tokens,
        }
      end
    end

    def activate_atoms_for(chunk_ids, tier:)
      AtomScorer.new(query: @query).activate_for(chunk_ids: chunk_ids, tier: tier, limit: @top_k)
    end

    def current_triples_for(chunk_ids)
      atom_ids = Atom.where(chunk_id: chunk_ids).pluck(:id)
      return [] if atom_ids.empty?
      Triple.where(source_atom_id: atom_ids).currently_valid.limit(12).to_a
    end

    def tier_for(top_score)
      th = MSAM_CONFIG[:tier_thresholds]
      return :high   if top_score >= th[:high]
      return :medium if top_score >= th[:medium]
      return :low    if top_score >= th[:low]
      :none
    end

    def apply_gating(top_chunk_ids, atoms, triples, tier)
      case tier
      when :high
        Result.new(atoms: atoms.first(@top_k), chunks: top_chunk_ids,
                   triples: triples, tier: tier, diagnostics: @diag)
      when :medium
        Result.new(atoms: atoms.first(3), chunks: top_chunk_ids.first(3),
                   triples: [], tier: tier, diagnostics: @diag)
      when :low
        Result.new(atoms: atoms.first(1), chunks: [],
                   triples: [], tier: tier, diagnostics: @diag)
      else
        empty(tier)
      end
    end

    def empty(tier)
      Result.new(atoms: [], chunks: [], triples: [], tier: tier, diagnostics: @diag)
    end
  end
end
