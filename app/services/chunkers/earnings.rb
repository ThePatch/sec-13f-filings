# Earnings-call chunker. Splits on `[Speaker — Title]` boundaries; a chunk
# never crosses speakers. Within a single long speaker turn, soft-splits on
# paragraph boundaries when the running token count exceeds MAX_TOKENS.
#
# Expected input format (the AlphaVantage / Finnhub fetchers shape transcripts
# into this layout):
#
#   [Tim Cook — CEO]
#   We saw strong demand …
#
#   [Luca Maestri — CFO]
#   Services revenue grew 16 percent …
module Chunkers
  class Earnings < Base
    MAX_TOKENS = 200
    SPEAKER_RX = /\A\[([^\]]+)\]\s*$/m

    def chunks
      out = []
      cursor = 0
      current = nil  # { speaker:, text:, start_char: }

      @text.split(/\n/).each do |line|
        line_start = @text.index(line, cursor) || cursor
        cursor = line_start + line.length

        if (m = line.match(SPEAKER_RX))
          out.concat(flush(current))
          current = { speaker: m[1].strip, text: "", start_char: line_start + line.length + 1 }
          next
        end

        if current
          current[:text] = current[:text].empty? ? line : "#{current[:text]}\n#{line}"
          if estimate_tokens(current[:text]) > MAX_TOKENS
            split_at = current[:text].rindex("\n\n")
            if split_at && split_at > 50
              head = current[:text][0...split_at]
              tail = current[:text][(split_at + 2)..] || ""
              out.concat(emit_one(current.merge(text: head)))
              current = { speaker: current[:speaker], text: tail, start_char: current[:start_char] + split_at + 2 }
            else
              out.concat(emit_one(current))
              current = { speaker: current[:speaker], text: "", start_char: cursor }
            end
          end
        end
      end
      out.concat(flush(current))
      out
    end

    private

    def flush(state)
      return [] unless state && state[:text].to_s.strip.length > 0
      emit_one(state)
    end

    def emit_one(state)
      text = state[:text].strip
      [{
        text:        text,
        token_count: estimate_tokens(text),
        start_char:  state[:start_char],
        end_char:    state[:start_char] + text.length,
        speaker:     state[:speaker],
        section:     nil,
      }]
    end
  end
end
