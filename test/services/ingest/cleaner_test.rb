require 'test_helper'

module Ingest
  class CleanerTest < ActiveSupport::TestCase
    test 'normalize_whitespace collapses runs and trims' do
      assert_equal "a b", Ingest::Cleaner.normalize_whitespace("a    b   ")
      assert_equal "a\n\nb", Ingest::Cleaner.normalize_whitespace("a\n\n\n\nb")
    end

    test 'strip_html returns text when HTML, passes through when plain' do
      assert_equal "Hello world", Ingest::Cleaner.strip_html("<p>Hello world</p>")
      assert_equal "Plain text", Ingest::Cleaner.strip_html("Plain text")
    end

    test 'clean removes forward-looking boilerplate' do
      input = "Real content.\n\nForward-looking statements: These materials contain " \
              "forward-looking statements about future results. Actual results may differ."
      out = Ingest::Cleaner.clean(input)
      refute_match(/forward[- ]looking/i, out)
      assert_includes out, "Real content."
    end

    test 'clean strips Reuters syndication marker' do
      input = "Apple raised guidance.\n\nThis article was syndicated by Reuters. © 2026 Reuters."
      out = Ingest::Cleaner.clean(input)
      assert_includes out, "Apple raised guidance."
      refute_match(/syndicated by reuters/i, out)
    end

    test 'clean removes cookie banner' do
      input = "Real news.\n\nWe use cookies to improve your experience.\n\nMore real news."
      out = Ingest::Cleaner.clean(input)
      refute_match(/we use cookies/i, out)
      assert_includes out, "Real news."
      assert_includes out, "More real news."
    end
  end
end
