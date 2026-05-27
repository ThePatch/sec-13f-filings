# app/services/ai/router.rb
#
# Dispatches chat requests to the right provider client and assembles the
# system prompt from two sources:
#
#   1. Retrieval::HybridRetriever — semantic atoms + chunks pulled from the
#      v2 compression layer (ColBERT + MSAM). Returns confidence-tiered context.
#   2. ContextBuilder (legacy) — structured filer/filing/cusip/period blocks
#      lifted directly from 13F data. Useful when the user navigates to a
#      specific entity even if no atoms exist for it yet.
#
# Both feed a single system prompt template (app/prompts/system_chat.md).

module Ai
  class Router
    PROVIDERS = {
      'claude'     => 'Ai::AnthropicClient',
      'openai'     => 'Ai::OpenAiClient',
      'groq'       => 'Ai::GroqClient',
      'openrouter' => 'Ai::OpenRouterClient',
      'nim'        => 'Ai::NimClient',
      'ollama'     => 'Ai::OllamaClient',
    }.freeze

    SYSTEM_TEMPLATE_PATH = Rails.root.join('app/prompts/system_chat.md')

    def initialize(session_id:)
      @session_id = session_id
    end

    def chat(provider:, model:, messages:, context: [], **opts)
      client = client_for(provider)
      assembled = build_system_prompt(messages: messages, context_refs: context)
      result = client.chat(messages: messages, model: model, system_prompt: assembled[:prompt], **opts)
      touch_config(provider)
      message_record(
        provider: provider, model: model, result: result, context: context,
        retrieval: assembled[:retrieval],
      )
    end

    def stream_chat(provider:, model:, messages:, context: [], **opts, &block)
      client = client_for(provider)
      assembled = build_system_prompt(messages: messages, context_refs: context)
      result = client.stream_chat(messages: messages, model: model, system_prompt: assembled[:prompt], **opts, &block)
      touch_config(provider)
      result
    end

    private

    def build_system_prompt(messages:, context_refs:)
      query = (messages.last && (messages.last[:content] || messages.last['content'])).to_s

      retrieval = Retrieval::HybridRetriever.new(
        query: query,
        context_refs: context_refs,
        session_id: @session_id,
      ).retrieve

      atoms_block   = format_atoms(retrieval.atoms)
      chunks_block  = format_chunks(retrieval.chunks)
      legacy_block  = ContextBuilder.new.build_blocks_only(context_refs)

      prompt = SYSTEM_TEMPLATE_PATH.read
                 .sub('{{ATOMS}}',          atoms_block)
                 .sub('{{CHUNKS}}',         chunks_block)
                 .sub('{{LEGACY_CONTEXT}}', legacy_block)

      { prompt: prompt, retrieval: retrieval }
    end

    def format_atoms(atoms)
      return '' if atoms.blank?
      body = atoms.map do |a|
        "[a:#{a.id}] (#{a.profile}, stab=#{a.stability.to_f.round(2)})\n#{a.content}"
      end.join("\n\n")
      "ATOMS (compressed memory; cite as `[a:<id>]`):\n```\n#{body}\n```"
    end

    def format_chunks(chunk_ids)
      return '' if chunk_ids.blank?
      rows = Chunk.where(id: chunk_ids).pluck(:id, :text, :document_id)
      # Preserve the order from retrieval
      by_id = rows.index_by(&:first)
      body  = chunk_ids.filter_map { |id| by_id[id] }.map do |id, text, _doc_id|
        "[c:#{id}]\n#{text}"
      end.join("\n\n")
      "CHUNKS (raw source spans; cite as `[c:<id>]`):\n```\n#{body}\n```"
    end

    def client_for(provider)
      klass_name = PROVIDERS[provider.to_s] || raise(ArgumentError, "unknown provider: #{provider}")
      config = AiProviderConfig.find_by(session_id: @session_id, provider: provider.to_s)
      key = config&.api_key
      if key.blank? && provider.to_s != 'ollama'
        raise "no api key configured for #{provider}"
      end
      klass = klass_name.constantize
      klass.new(api_key: key, endpoint: config&.endpoint)
    end

    def touch_config(provider)
      AiProviderConfig.where(session_id: @session_id, provider: provider.to_s).update_all(last_used_at: Time.current)
    end

    def message_record(provider:, model:, result:, context:, retrieval:)
      {
        id: SecureRandom.uuid,
        role: 'assistant',
        body: result[:body],
        model: { provider: provider, model: model },
        tokens_in: result[:tokens_in],
        tokens_out: result[:tokens_out],
        cost_usd: result[:cost_usd],
        latency_ms: result[:latency_ms],
        confidence_tier: retrieval&.tier,
        citations: build_citations(result[:body], context, retrieval),
        created_at: Time.current.iso8601,
      }
    end

    # Parse `[a:N]` and `[c:N]` markers from the LLM body. The returned array is
    # what the frontend renders as pills (T-605 wires the UI).
    def build_citations(body, context_refs, retrieval)
      body = body.to_s
      atom_ids  = body.scan(/\[a:(\d+)\]/).flatten.map(&:to_i).uniq
      chunk_ids = body.scan(/\[c:(\d+)\]/).flatten.map(&:to_i).uniq

      atom_rows  = atom_ids.any?  ? Atom.where(id: atom_ids).pluck(:id, :content).to_h : {}
      chunk_rows = chunk_ids.any? ? Chunk.where(id: chunk_ids).pluck(:id, :text).to_h  : {}

      citations = []
      atom_ids.each  { |id| citations << { type: 'atom',  id: id, label: (atom_rows[id]  || '').slice(0, 80) } }
      chunk_ids.each { |id| citations << { type: 'chunk', id: id, label: (chunk_rows[id] || '').slice(0, 80) } }

      # Preserve v1 navigational refs so the frontend can still highlight them
      Array(context_refs).each do |c|
        citations << {
          type: 'ref',
          ref_type: c[:ref_type] || c['ref_type'],
          ref_id:   c[:ref_id]   || c['ref_id'],
          label:    (c[:ref_type] || c['ref_type']).to_s,
        }
      end

      citations
    end
  end

  # Resolves v1-style "context refs" (filer/filing/cusip/period) into structured
  # context blocks. v2's HybridRetriever handles semantic retrieval; this still
  # provides the structured 13F data that has no atom yet.
  class ContextBuilder
    SYSTEM_BASE = <<~SYS.freeze
      You are an AI assistant analyzing SEC Form 13F institutional holdings filings.
      Be concise, factual, and numerical. When citing values, use the actual numbers
      from the context blocks below — never invent data.

      Format responses as HTML with <b>, <i>, <span class="pos|neg|mono">.
      Numbers in the body should use the same units as the source data.
    SYS

    def build(context_refs)
      blocks = blocks_for(context_refs)
      return SYSTEM_BASE if blocks.empty?
      "#{SYSTEM_BASE}\n\nCONTEXT BLOCKS:\n#{blocks.join("\n\n")}"
    end

    # Returns just the structured blocks (no system base) so the v2 router can
    # fold them into its own template.
    def build_blocks_only(context_refs)
      blocks = blocks_for(context_refs)
      return '' if blocks.empty?
      "LEGACY CONTEXT BLOCKS:\n#{blocks.join("\n\n")}"
    end

    private

    def blocks_for(context_refs)
      Array(context_refs).map do |ref|
        type = (ref[:ref_type] || ref['ref_type']).to_s
        id   = ref[:ref_id]   || ref['ref_id']
        case type
        when 'filer'   then build_filer_block(id)
        when 'filing'  then build_filing_block(id)
        when 'cusip', 'holding' then build_cusip_block(id)
        when 'period'  then build_period_block(id)
        end
      end.compact
    end

    def build_filer_block(cik)
      filer = ThirteenFFiler.find_by(cik: cik)
      return nil unless filer
      latest = ThirteenF.where(cik: cik).order(date_filed: :desc).first
      payload = {
        cik: filer.cik, name: filer.name,
        latest_filing: latest&.as_json(except: heavy_columns(ThirteenF)),
      }
      "FILER #{filer.name} (CIK #{cik})\n#{payload.to_json}"
    end

    def build_filing_block(filing_id)
      f = ThirteenF.find_by(id: filing_id)
      return nil unless f
      holdings = AggregateHolding.where(thirteen_f_id: f.id).order(value: :desc).limit(50).as_json
      payload = f.as_json(except: heavy_columns(ThirteenF)).merge(top_holdings: holdings)
      label = "#{f.try(:name) || f.cik} #{f.try(:report_year)}-Q#{f.try(:report_quarter)}"
      "FILING #{label}\n#{payload.to_json}"
    end

    def build_cusip_block(cusip)
      lookup = CompanyCusipLookup.find_by(cusip: cusip)
      return nil unless lookup
      "CUSIP #{cusip} (#{lookup.try(:symbol)} — #{lookup.try(:issuer_name) || lookup.try(:name)})"
    end

    def build_period_block(period)
      "PERIOD #{period}"
    end

    def heavy_columns(klass)
      (%i[primary_doc_xml info_table_xml] & klass.column_names.map(&:to_sym))
    end
  end
end
