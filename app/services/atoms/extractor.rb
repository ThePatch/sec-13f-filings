# LLM-based extraction of atoms from a chunk. Bypasses Ai::Router (which needs
# a per-session AiProviderConfig) — extraction is a background job pattern, so
# it uses Ai::AnthropicClient directly with the system ENV key, mirroring how
# GenerateInsightsJob already operates.
require "digest"
require "json"

module Atoms
  class Extractor
    PROMPT_PATH = Rails.root.join("app", "prompts", "extract_atoms.md")
    MAX_RETRIES = 1

    def initialize(model: nil)
      @model    = model || MSAM_CONFIG[:extraction_model]
      @api_key  = ENV["ANTHROPIC_API_KEY"]
    end

    # Returns the array of created Atom IDs (skips dedup'd).
    def extract(chunk:)
      raise ExtractionError, "ANTHROPIC_API_KEY not set — atom extraction disabled" if @api_key.blank?

      prompt = build_prompt(chunk)
      response_body = call_llm(prompt)
      data = parse_or_raise(response_body)
      persist!(chunk: chunk, atoms_data: data.fetch("atoms", []))
    end

    private

    def build_prompt(chunk)
      doc = chunk.document
      company = doc&.company
      File.read(PROMPT_PATH)
          .gsub("{{CHUNK_TEXT}}",     chunk.text.to_s)
          .gsub("{{DOC_TYPE}}",       doc&.doc_type.to_s)
          .gsub("{{COMPANY_NAME}}",   company&.name.to_s)
          .gsub("{{COMPANY_TICKER}}", company&.ticker.to_s)
          .gsub("{{PUBLISHED_AT}}",   doc&.published_at&.iso8601.to_s)
          .gsub("{{DOCUMENT_TITLE}}", doc&.title.to_s)
    end

    def call_llm(prompt, attempt: 0)
      client = Ai::AnthropicClient.new(api_key: @api_key)
      response = client.chat(
        messages: [{ role: "user", content: prompt }],
        model:    @model,
        system_prompt: "Return ONLY valid JSON. No prose before or after.",
        max_tokens: 1200,
      )
      response[:body].to_s
    rescue => e
      if attempt < MAX_RETRIES
        sleep 1
        call_llm(prompt + "\n\nRESPONSE MUST BE PURE JSON. No prose.", attempt: attempt + 1)
      else
        raise ExtractionError, "LLM call failed: #{e.class}: #{e.message}"
      end
    end

    def parse_or_raise(text)
      json_str = text.to_s.match(/\{.*\}/m)&.to_s
      raise ExtractionError, "no JSON in response" unless json_str
      JSON.parse(json_str)
    rescue JSON::ParserError => e
      raise ExtractionError, "invalid JSON: #{e.message}"
    end

    def persist!(chunk:, atoms_data:)
      ids = []
      Array(atoms_data).each do |data|
        content = data["content"].to_s.strip
        next if content.empty?

        hash = Digest::SHA256.hexdigest(content)
        existing = Atom.find_by(content_hash: hash, company_id: chunk.document&.company_id)
        if existing
          ids << existing.id
          next
        end

        atom = Atom.create!(
          chunk_id:            chunk.id,
          document_id:         chunk.document_id,
          company_id:          chunk.document&.company_id,
          content:             content,
          content_hash:        hash,
          token_count:         data["token_count"] || estimate_tokens(content),
          profile:             data["profile"]      || "standard",
          source_quote:        data["source_quote"],
          topics:              Array(data["topics"]),
          arousal:             clamp(data["arousal"].to_f, 0.0, 1.0),
          valence:             clamp(data["valence"].to_f, -1.0, 1.0),
          encoding_confidence: 0.85,
          state:               "active",
          stream:              stream_for(chunk.document&.doc_type),
        )
        ids << atom.id
      end
      ids
    end

    def estimate_tokens(text)
      (text.length / 4.0).ceil
    end

    def clamp(value, min, max)
      [[value, min].max, max].min
    end

    def stream_for(doc_type)
      case doc_type.to_s
      when "earnings_call", "news"           then "episodic"
      when "sec_8k", "sec_10q"               then "semantic"
      when "letter", "ir_press", "sec_other" then "semantic"
      else                                         "semantic"
      end
    end
  end
end
