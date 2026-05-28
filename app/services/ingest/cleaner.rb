# T-537 — boilerplate/whitespace cleaning. Pattern catalog lives in
# config/boilerplate_patterns.yml so non-engineers can extend it.
require "yaml"
require "nokogiri"

module Ingest
  class Cleaner
    CATALOG_PATH = Rails.root.join("config/boilerplate_patterns.yml")

    def self.clean(text)
      new.clean(text)
    end

    def self.normalize_whitespace(text)
      text.to_s.gsub(/\r\n?/, "\n").gsub(/[ \t]+/, " ").gsub(/\n{3,}/, "\n\n").strip
    end

    def self.strip_html(text)
      return text.to_s if text.to_s !~ /<[^>]+>/
      Nokogiri::HTML(text.to_s).text
    end

    def initialize(catalog_path: CATALOG_PATH)
      @catalog = YAML.safe_load(File.read(catalog_path))["patterns"]
    end

    def clean(text)
      out = self.class.normalize_whitespace(self.class.strip_html(text))
      @catalog.each do |entry|
        rx = Regexp.new(entry.fetch("pattern"))
        out = out.gsub(rx, entry.fetch("replace", ""))
      end
      out.strip
    end
  end
end
