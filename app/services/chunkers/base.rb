module Chunkers
  class Base
    # text: cleaned plain text. Returns Array<Hash> with keys:
    #   :text, :token_count, :start_char, :end_char, :speaker, :section
    def initialize(text)
      @text = text.to_s
    end

    def chunks
      raise NotImplementedError
    end

    protected

    def estimate_tokens(text)
      (text.length / 4.0).ceil
    end
  end
end
