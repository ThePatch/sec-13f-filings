require "digest"
require "nokogiri"

module Ingest
  class SecFilingFetcher < BaseFetcher
    FORM_TYPES = ["8-K", "10-Q", "DEF 14A", "PX14A6G"].freeze
    EDGAR_BASE = "https://www.sec.gov".freeze
    POLL_RPM   = 60  # polite cap; SEC enforces 10 req/s globally

    # Pulls the current EDGAR feed for each form type, ingests anything updated
    # since `since`. Returns the array of created Document IDs.
    def fetch_recent(since: 24.hours.ago)
      created = []
      FORM_TYPES.each do |form|
        respect_rate_limit("sec", requests_per_minute: POLL_RPM)
        entries = fetch_form_index(form)
        entries.each do |entry|
          updated_at = safe_parse_time(entry[:updated])
          next unless updated_at && updated_at >= since
          doc = ingest_filing(entry)
          created << doc.id if doc&.respond_to?(:id)
        end
      end
      created
    end

    private

    def fetch_form_index(form_type)
      with_retry do
        response = HTTParty.get(
          "#{EDGAR_BASE}/cgi-bin/browse-edgar",
          query: { action: "getcurrent", type: form_type, output: "atom", count: 100 },
          headers: { "User-Agent" => sec_user_agent, "Accept" => "application/atom+xml" },
          timeout: 30,
        )
        unless response.success?
          raise FetcherError, "sec returned #{response.code}: #{response.body.to_s.slice(0, 200)}"
        end
        parse_atom_entries(response.body, form_type)
      end
    end

    def parse_atom_entries(xml, form_type)
      doc = Nokogiri::XML(xml)
      doc.remove_namespaces!
      doc.xpath("//entry").map do |e|
        link = e.at("link")&.attr("href")
        next nil unless link
        accession = e.at("id")&.text&.match(/accession-number=([\w-]+)/)&.[](1)
        next nil unless accession

        {
          accession: accession,
          title:     e.at("title")&.text,
          updated:   e.at("updated")&.text,
          link:      link,
          form_type: form_type,
        }
      end.compact
    end

    def ingest_filing(entry)
      dedup_by_source_ref(source: "sec", ref: entry[:accession]) do
        body_text = fetch_filing_body(entry[:link])
        next nil if body_text.blank?

        cik     = entry[:link].match(%r{/data/(\d+)/})&.[](1)&.rjust(10, "0")
        published = safe_parse_time(entry[:updated]) || Time.current

        doc = Document.create!(
          source:        "sec",
          source_ref:    entry[:accession],
          company_id:    cik && Company.find_by(cik: cik)&.id,
          doc_type:      doc_type_for(entry[:form_type]),
          title:         entry[:title],
          authors:       [],
          published_at:  published,
          raw_url:       entry[:link],
          raw_text:      body_text,
          word_count:    body_text.split.size,
          content_hash:  Digest::SHA256.hexdigest(body_text),
          metadata:      { form_type: entry[:form_type], cik: cik, accession: entry[:accession] },
        )

        # For 8-K, also pull Exhibit 99.1 (press release) when present and link
        # the two via metadata.parent_document_id.
        if entry[:form_type] == "8-K"
          exhibit_text, exhibit_url = fetch_exhibit_99_1(entry[:link])
          if exhibit_text.present?
            Document.create!(
              source:        "sec",
              source_ref:    "#{entry[:accession]}/exhibit-99.1",
              company_id:    doc.company_id,
              doc_type:      "ir_press",
              title:         "#{entry[:title]} — Exhibit 99.1",
              authors:       [],
              published_at:  published,
              raw_url:       exhibit_url,
              raw_text:      exhibit_text,
              word_count:    exhibit_text.split.size,
              content_hash:  Digest::SHA256.hexdigest(exhibit_text),
              metadata:      { parent_document_id: doc.id, accession: entry[:accession], exhibit: "99.1" },
            )
          end
        end

        doc
      end
    end

    def fetch_filing_body(filing_url)
      response = with_retry { HTTParty.get(filing_url, headers: { "User-Agent" => sec_user_agent }, timeout: 30) }
      return "" unless response.success?
      html = Nokogiri::HTML(response.body)
      primary = html.css("table.tableFile a, table a").map { |a| a["href"] }
                    .find { |h| h&.match?(/\.htm$|\.txt$/i) }
      return "" unless primary
      url = primary.start_with?("/") ? "#{EDGAR_BASE}#{primary}" : primary
      with_retry do
        doc_response = HTTParty.get(url, headers: { "User-Agent" => sec_user_agent }, timeout: 30)
        Nokogiri::HTML(doc_response.body).text.squeeze("\n").strip
      end
    end

    def fetch_exhibit_99_1(filing_url)
      response = HTTParty.get(filing_url, headers: { "User-Agent" => sec_user_agent }, timeout: 30)
      return ["", nil] unless response.success?
      html = Nokogiri::HTML(response.body)
      ex_link = html.css("table.tableFile a, table a").find { |a| a.text =~ /99\.1/i || a["href"] =~ /ex99[\-_]?1/i }
      return ["", nil] unless ex_link
      href = ex_link["href"]
      url  = href.start_with?("/") ? "#{EDGAR_BASE}#{href}" : href
      doc_response = HTTParty.get(url, headers: { "User-Agent" => sec_user_agent }, timeout: 30)
      [Nokogiri::HTML(doc_response.body).text.squeeze("\n").strip, url]
    rescue StandardError
      ["", nil]
    end

    def doc_type_for(form_type)
      case form_type
      when "8-K"  then "sec_8k"
      when "10-Q" then "sec_10q"
      else             "sec_other"
      end
    end

    def safe_parse_time(str)
      Time.parse(str.to_s)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
