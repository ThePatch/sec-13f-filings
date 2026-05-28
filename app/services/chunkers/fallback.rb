# Paragraph chunker — used when a document type doesn't have a specialized
# chunker yet (T-536 in Phase 10 replaces this with per-doc-type chunkers
# for earnings calls, news, SEC filings, and shareholder letters).
module Chunkers
  class Fallback < Base
    TARGET_TOKENS = 200

    def chunks
      out = []
      cursor = 0
      buffer = +''
      buffer_start = 0

      paragraphs = @text.split(/\n\s*\n+/)
      paragraphs.each do |p|
        para = p.strip
        next if para.empty?

        start_in_text = @text.index(para, cursor) || cursor
        para_tokens = estimate_tokens(para)

        if buffer.empty?
          buffer       = para
          buffer_start = start_in_text
        elsif estimate_tokens(buffer) + para_tokens <= TARGET_TOKENS
          buffer << "\n\n" << para
        else
          out << emit_chunk(buffer, buffer_start)
          buffer       = para
          buffer_start = start_in_text
        end

        cursor = start_in_text + para.length
      end

      out << emit_chunk(buffer, buffer_start) unless buffer.empty?
      out
    end

    private

    def emit_chunk(text, start_char)
      {
        text:        text,
        token_count: estimate_tokens(text),
        start_char:  start_char,
        end_char:    start_char + text.length,
        speaker:     nil,
        section:     nil,
      }
    end
  end
end
