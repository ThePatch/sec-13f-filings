require 'test_helper'

module Chunkers
  class EarningsTest < ActiveSupport::TestCase
    test 'never produces a chunk straddling two speakers' do
      text = <<~T
        [Tim Cook — CEO]
        We saw record iPhone revenue.

        Strong demand for iPhone 17 Pro drove most of the upside in the September quarter.

        [Luca Maestri — CFO]
        Services revenue grew 16 percent year over year.
      T

      chunks = Chunkers::Earnings.new(text).chunks

      speakers = chunks.map { |c| c[:speaker] }.uniq
      assert_includes speakers, "Tim Cook — CEO"
      assert_includes speakers, "Luca Maestri — CFO"
      chunks.each do |c|
        # Each chunk's body should not contain a speaker header for someone else.
        speaker_headers = c[:text].scan(/^\[([^\]]+)\]\s*$/).flatten
        assert speaker_headers.empty?, "chunk contains nested speaker headers: #{speaker_headers}"
      end
    end

    test 'long speaker turn soft-splits at paragraph boundary' do
      long = ("This is a sentence. " * 60).strip
      text = "[Tim Cook — CEO]\n#{long}\n\n#{long}"
      chunks = Chunkers::Earnings.new(text).chunks
      assert chunks.size >= 2, "long turn should produce multiple chunks (got #{chunks.size})"
      chunks.each { |c| assert_equal "Tim Cook — CEO", c[:speaker] }
    end
  end
end
