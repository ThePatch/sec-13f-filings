require "json"

module Atoms
  class TripleExtractor
    PROMPT_PATH = Rails.root.join("app", "prompts", "extract_triples.md")

    def initialize(model: nil)
      @model   = model || MSAM_CONFIG[:extraction_model]
      @api_key = ENV["ANTHROPIC_API_KEY"]
    end

    # chunk: a Chunk record
    # atom_ids: array of Atom IDs already extracted from the chunk (provides
    #           context for the triple prompt + the source_atom_id linkage).
    # Returns the array of created Triple IDs.
    def extract(chunk:, atom_ids: [])
      raise TripleExtractionError, "ANTHROPIC_API_KEY not set" if @api_key.blank?

      atoms = Atom.where(id: atom_ids).order(:id).to_a
      prompt = build_prompt(chunk: chunk, atoms: atoms)
      body = call_llm(prompt)
      data = parse_or_raise(body)
      persist!(chunk: chunk, atoms: atoms, triples_data: data.fetch("triples", []))
    end

    private

    def build_prompt(chunk:, atoms:)
      doc = chunk.document
      company = doc&.company
      atoms_json = atoms.map { |a| { content: a.content, source_quote: a.source_quote, topics: a.topics } }.to_json
      File.read(PROMPT_PATH)
          .gsub("{{CHUNK_TEXT}}",     chunk.text.to_s)
          .gsub("{{ATOMS_JSON}}",     atoms_json)
          .gsub("{{DOC_TYPE}}",       doc&.doc_type.to_s)
          .gsub("{{COMPANY_NAME}}",   company&.name.to_s)
          .gsub("{{COMPANY_TICKER}}", company&.ticker.to_s)
          .gsub("{{PUBLISHED_AT}}",   doc&.published_at&.iso8601.to_s)
    end

    def call_llm(prompt)
      Ai::AnthropicClient.new(api_key: @api_key).chat(
        messages: [{ role: "user", content: prompt }],
        model:    @model,
        system_prompt: "Return ONLY valid JSON. No prose before or after.",
        max_tokens: 1200,
      )[:body].to_s
    rescue => e
      raise TripleExtractionError, "LLM call failed: #{e.class}: #{e.message}"
    end

    def parse_or_raise(text)
      json_str = text.to_s.match(/\{.*\}/m)&.to_s
      raise TripleExtractionError, "no JSON in response" unless json_str
      JSON.parse(json_str)
    rescue JSON::ParserError => e
      raise TripleExtractionError, "invalid JSON: #{e.message}"
    end

    def persist!(chunk:, atoms:, triples_data:)
      # Highest-confidence atom is the source_atom_id default.
      source_atom = atoms.max_by { |a| a.encoding_confidence.to_f } || atoms.first
      ids = []

      ActiveRecord::Base.transaction do
        Array(triples_data).each do |data|
          subj = data["subject"].to_s.strip
          pred = data["predicate"].to_s.strip
          obj  = data["object"].to_s.strip
          next if subj.empty? || pred.empty? || obj.empty?

          # Auto-close any currently-valid triple with the same (subject,
          # predicate) so the new one becomes the authoritative current row.
          # Only close when the object actually changes — same SPO is a
          # restatement, not an update.
          existing = Triple.where(subject: subj, predicate: pred, valid_until: nil).first
          if existing && existing.object != obj
            existing.update!(valid_until: Time.current)
          end

          triple = Triple.create!(
            subject:        subj,
            predicate:      pred,
            object:         obj,
            confidence:     clamp(data["confidence"].to_f, 0.0, 1.0),
            valid_from:     Time.current,
            source_atom_id: source_atom&.id,
            metadata:       { chunk_id: chunk.id, document_id: chunk.document_id },
          )
          ids << triple.id
        rescue ActiveRecord::RecordNotUnique
          # (subject, predicate, object, valid_from) already exists — skip.
          next
        end
      end
      ids
    end

    def clamp(value, min, max)
      [[value, min].max, max].min
    end
  end
end
