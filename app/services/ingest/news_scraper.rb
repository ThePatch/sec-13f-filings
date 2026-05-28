require "nokogiri"

module Ingest
  # Lightweight readability-style article body extractor. We avoid bringing in
  # `readability-rb` or `goose-rb` (both ageing, large dep surface). Heuristic:
  # find the DOM node with the highest paragraph-text density and return its
  # inner text. Good enough for most news sites; falls back to whole-document
  # text when ambiguous. Subclasses can override on a per-site basis later.
  class NewsScraper
    MIN_PARAGRAPH_CHARS = 80

    def self.extract(url:)
      new.extract(url: url)
    end

    def extract(url:)
      response = HTTParty.get(url, headers: {
        "User-Agent" => ENV.fetch("SCRAPER_USER_AGENT", "F13ExplorerBot/1.0"),
        "Accept"     => "text/html,application/xhtml+xml",
      }, timeout: 20)
      return { ok: false, error: "http_#{response.code}" } unless response.success?

      html = Nokogiri::HTML(response.body)
      strip_noise!(html)

      best, body = pick_dense_container(html)
      title = html.at("title")&.text&.strip
      if body.to_s.strip.length < MIN_PARAGRAPH_CHARS
        # Fallback: whole-document text.
        body = html.css("body").text
      end
      { ok: true, title: title, text: Ingest::Cleaner.normalize_whitespace(body), container: best }
    rescue => e
      { ok: false, error: e.class.name }
    end

    private

    def strip_noise!(html)
      %w[script style noscript header nav footer aside form iframe svg
         .ad .ads .advertisement .nav .footer .header .sidebar].each do |sel|
        html.css(sel).each(&:remove)
      end
    end

    def pick_dense_container(html)
      candidates = %w[article main [role=main] #content .article-body .post-content .entry-content]
      candidates.each do |sel|
        node = html.css(sel).first
        next unless node
        text = paragraph_text(node)
        return [sel, text] if text.length >= MIN_PARAGRAPH_CHARS
      end

      # Score every <div>/<section> by total paragraph text length.
      best_node = nil
      best_len  = 0
      html.css("div, section").each do |node|
        len = paragraph_text(node).length
        if len > best_len
          best_node = node
          best_len  = len
        end
      end
      [best_node&.name, best_node ? paragraph_text(best_node) : ""]
    end

    def paragraph_text(node)
      node.css("p").map(&:text).select { |t| t.length >= MIN_PARAGRAPH_CHARS }.join("\n\n")
    end
  end
end
