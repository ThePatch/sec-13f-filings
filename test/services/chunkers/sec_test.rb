require 'test_helper'

module Chunkers
  class SecTest < ActiveSupport::TestCase
    test 'sets section from Item boundaries' do
      text = <<~T
        Item 2.02 Results of Operations and Financial Condition

        Apple Inc. announced earnings on October 31, 2025.

        Item 8.01 Other Events

        The board approved a $90B share buyback.
      T
      chunks = Chunkers::Sec.new(text).chunks
      sections = chunks.map { |c| c[:section] }.compact.uniq
      assert_includes sections, "Item 2.02"
      assert_includes sections, "Item 8.01"
    end

    test 'falls back gracefully when text has no Item headers' do
      text = "Just some regular text.\n\nWith two paragraphs."
      chunks = Chunkers::Sec.new(text).chunks
      assert chunks.size >= 1
    end
  end
end
