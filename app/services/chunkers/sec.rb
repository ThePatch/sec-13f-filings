# SEC chunker. Splits on Item boundaries ("Item 2.02 …", "Item 8.01 …").
# Each chunk carries a `section` value like "Item 2.02".
module Chunkers
  class Sec < Base
    MAX_TOKENS  = 240
    ITEM_RX     = /^(Item\s+\d+\.\d+(?:\([a-z]\))?)/i

    def chunks
      out = []
      pos = 0
      sections = split_into_sections
      sections.each do |sec|
        next if sec[:text].strip.empty?

        if estimate_tokens(sec[:text]) <= MAX_TOKENS
          out << emit(sec[:text], pos, sec[:section])
          pos += sec[:text].length
        else
          # split section into ≤MAX_TOKENS sub-chunks at paragraph boundaries
          paragraphs = sec[:text].split(/\n\s*\n+/)
          buf = +""
          buf_start = pos
          paragraphs.each do |p|
            p = p.strip
            next if p.empty?

            if buf.empty?
              buf = p
            elsif estimate_tokens(buf) + estimate_tokens(p) <= MAX_TOKENS
              buf << "\n\n" << p
            else
              out << emit(buf, buf_start, sec[:section])
              pos      += buf.length
              buf       = p
              buf_start = pos
            end
          end
          unless buf.empty?
            out << emit(buf, buf_start, sec[:section])
            pos += buf.length
          end
        end
      end
      out
    end

    private

    def split_into_sections
      sections = []
      current_section = nil
      buf = +""

      @text.each_line do |line|
        if (m = line.match(ITEM_RX))
          sections << { section: current_section, text: buf } unless buf.strip.empty?
          current_section = m[1]
          buf = line
        else
          buf << line
        end
      end
      sections << { section: current_section, text: buf } unless buf.strip.empty?
      sections
    end

    def emit(text, start_char, section)
      stripped = text.strip
      { text: stripped, token_count: estimate_tokens(stripped),
        start_char: start_char, end_char: start_char + stripped.length,
        speaker: nil, section: section }
    end
  end
end
