# Hourly job. For each non-tombstone atom:
#   1. Recompute retrievability R = e^(-Δt/stability)
#   2. Transition state:
#        active  → fading   when R < R_TO_FADING
#        fading  → dormant  when R < R_TO_DORMANT
#   3. On active→fading, compact the profile (full → standard → lightweight)
#      via the compact_atom.md prompt.
#   4. Pinned atoms are exempt from decay.
#   5. Decay never tombstones — that's a manual op.
require "json"

module Atoms
  class DecayJob < ApplicationJob
    queue_as :default

    R_TO_FADING  = MSAM_CONFIG.dig(:decay, :active_to_fading_r)
    R_TO_DORMANT = MSAM_CONFIG.dig(:decay, :fading_to_dormant_r)

    def perform
      stats = { scanned: 0, to_fading: 0, to_dormant: 0, compacted: 0, errors: 0 }

      Atom.where(state: %w[active fading]).where(is_pinned: false).find_in_batches(batch_size: 500) do |batch|
        batch.each do |atom|
          stats[:scanned] += 1
          r = retrievability(atom)
          atom.retrievability = r

          case atom.state
          when "active"
            if r < R_TO_FADING
              atom.state = "fading"
              compact_profile!(atom, stats: stats)
              stats[:to_fading] += 1
              log_transition(atom, from: "active", to: "fading", r: r)
            end
          when "fading"
            if r < R_TO_DORMANT
              atom.state = "dormant"
              stats[:to_dormant] += 1
              log_transition(atom, from: "fading", to: "dormant", r: r)
            end
          end

          atom.save!(touch: false)
        rescue => e
          stats[:errors] += 1
          Rails.logger.error("[atoms.decay] atom=#{atom.id}: #{e.class}: #{e.message}")
        end
      end

      Rails.logger.info("[atoms.decay] #{stats.inspect}")
      stats
    end

    private

    def retrievability(atom)
      return 1.0 unless atom.last_accessed_at
      delta_hours = (Time.current - atom.last_accessed_at) / 3600.0
      Math.exp(-delta_hours / atom.stability_hours)
    end

    def compact_profile!(atom, stats:)
      target = case atom.profile
               when "full"     then "standard"
               when "standard" then "lightweight"
               else                 atom.profile
               end
      return if target == atom.profile

      api_key = ENV["ANTHROPIC_API_KEY"]
      return if api_key.blank?  # skip compaction silently if no system key

      prompt = File.read(Rails.root.join("app/prompts/compact_atom.md"))
                   .gsub("{{ATOM_JSON}}",       atom.attributes.slice("content", "profile", "source_quote", "topics").to_json)
                   .gsub("{{TARGET_PROFILE}}",  target)

      response = Ai::AnthropicClient.new(api_key: api_key).chat(
        messages: [{ role: "user", content: prompt }],
        model:    ENV.fetch("ATOM_COMPACT_MODEL", MSAM_CONFIG[:extraction_model]),
        system_prompt: "Return ONLY valid JSON.",
        max_tokens: 600,
      )

      json_str = response[:body].to_s.match(/\{.*\}/m)&.to_s
      data = json_str && JSON.parse(json_str)
      return unless data && data["content"].is_a?(String)

      atom.content     = data["content"]
      atom.token_count = data["token_count"] || (atom.content.length / 4.0).ceil
      atom.profile     = target
      stats[:compacted] += 1
    rescue => e
      Rails.logger.warn("[atoms.decay] compact failed for atom=#{atom.id}: #{e.message}")
    end

    def log_transition(atom, from:, to:, r:)
      Rails.logger.info(
        "[atoms.transition] id=#{atom.id} #{from}→#{to} R=#{r.round(3)} " \
        "stability=#{atom.stability} access_count=#{atom.access_count} " \
        "last=#{atom.last_accessed_at&.iso8601}"
      )
    end
  end
end
