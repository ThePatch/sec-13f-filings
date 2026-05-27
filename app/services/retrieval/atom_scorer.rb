# ACT-R activation scoring for atoms. Used inside HybridRetriever to rank the
# atoms attached to top chunks. Read handoff/v2/02_ARCHITECTURE.md "Activation"
# section before changing.
module Retrieval
  class AtomScorer
    def initialize(query:, query_embedding: nil)
      @query = query.to_s
      @query_embedding = query_embedding  # may be nil — graceful no-sim mode
    end

    def activate_for(chunk_ids:, tier:, limit: MSAM_CONFIG[:default_top_k])
      candidates = Atom.where(chunk_id: chunk_ids, state: %w[active fading]).to_a
      return [] if candidates.empty?

      candidates
        .map { |a| [a, activation(a)] }
        .sort_by { |_, score| -score }
        .first(limit)
        .map(&:first)
    end

    def activation(atom)
      cfg = MSAM_CONFIG[:activation]
      base       = Math.log([atom.access_count.to_i, 0].max + 1) * 0.5
      similarity = @query_embedding ? cosine(@query_embedding, atom.embedding) : 0.0
      recency    = recency_for(atom, half_life: cfg[:recency_half_life_hours])
      outcome    = outcome_score(atom, min: cfg[:min_outcomes_for_signal])
      stability  = atom.stability.to_f

      (base + similarity * cfg[:sim_weight] + recency * cfg[:recency_weight] + outcome * cfg[:outcome_weight]) * stability
    end

    # ─── Side effects on retrieval ─────────────────────────────────────
    def self.record_retrieval(atom_ids, session_id:)
      ids = Array(atom_ids).compact
      return if ids.empty?

      Atom.where(id: ids).update_all(
        access_count:     Arel.sql("access_count + 1"),
        last_accessed_at: Time.current,
      )
      record_co_retrievals(ids)
    end

    def self.record_co_retrievals(atom_ids)
      pairs = atom_ids.combination(2).map { |a, b| [[a, b].min, [a, b].max] }
      return if pairs.empty?

      values = pairs.map { |a, b| "(#{a.to_i}, #{b.to_i}, 1, NOW())" }.join(",")
      ActiveRecord::Base.connection.execute(<<~SQL)
        INSERT INTO atom_co_retrievals (atom_a, atom_b, count, last_at)
        VALUES #{values}
        ON CONFLICT (atom_a, atom_b)
        DO UPDATE SET count = atom_co_retrievals.count + 1, last_at = NOW();
      SQL
    end

    # ─── Spreading activation (used by T-526) ──────────────────────────
    def spreading_activation(atom_id, limit: 5)
      sql = <<~SQL
        SELECT CASE WHEN atom_a = $1 THEN atom_b ELSE atom_a END AS neighbor
        FROM atom_co_retrievals
        WHERE atom_a = $1 OR atom_b = $1
        ORDER BY count DESC, last_at DESC
        LIMIT $2
      SQL
      conn = ActiveRecord::Base.connection
      neighbor_ids = conn.exec_query(sql, "atom_spread", [atom_id.to_i, limit.to_i]).rows.flatten
      Atom.where(id: neighbor_ids)
    end

    private

    def cosine(a, b)
      return 0.0 if a.blank? || b.blank? || a.size != b.size
      dot = 0.0; na = 0.0; nb = 0.0
      a.each_with_index do |x, i|
        y = b[i]; dot += x * y; na += x * x; nb += y * y
      end
      return 0.0 if na.zero? || nb.zero?
      dot / (Math.sqrt(na) * Math.sqrt(nb))
    end

    def recency_for(atom, half_life:)
      return 0.0 unless atom.last_accessed_at
      hours = (Time.current - atom.last_accessed_at) / 3600.0
      Math.exp(-hours / half_life.to_f)
    end

    def outcome_score(atom, min:)
      outcomes = AtomOutcome.where(atom_id: atom.id).order(created_at: :desc).limit(50)
      return 0.0 if outcomes.size < min
      now = Time.current
      weighted = outcomes.sum do |o|
        age_days = (now - o.created_at) / 86_400.0
        o.signal.to_f * Math.exp(-age_days / 14.0)
      end
      weighted / outcomes.size.to_f
    end
  end
end
