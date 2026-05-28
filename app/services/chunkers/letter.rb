# Investor letter / shareholder communication chunker. Paragraph-based,
# 200 token target.
module Chunkers
  class Letter < Base
    MAX_TOKENS = 200

    def chunks
      Chunkers::News.new(@text).chunks.each { |c| c[:section] ||= "letter" }
    end
  end
end
