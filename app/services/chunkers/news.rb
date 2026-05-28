# News chunker. Paragraph-aware, 180-token target.
module Chunkers
  class News < Base
    MAX_TOKENS = 180

    def chunks
      out = []
      buf = +""
      buf_start = 0
      cursor = 0

      @text.split(/\n\s*\n+/).each do |para|
        para = para.strip
        next if para.empty?
        start_in_text = @text.index(para, cursor) || cursor

        if buf.empty?
          buf = para
          buf_start = start_in_text
        elsif estimate_tokens(buf) + estimate_tokens(para) <= MAX_TOKENS
          buf << "\n\n" << para
        else
          out << emit(buf, buf_start)
          buf = para
          buf_start = start_in_text
        end

        cursor = start_in_text + para.length
      end
      out << emit(buf, buf_start) unless buf.empty?
      out
    end

    private

    def emit(text, start_char)
      { text: text, token_count: estimate_tokens(text),
        start_char: start_char, end_char: start_char + text.length,
        speaker: nil, section: nil }
    end
  end
end
