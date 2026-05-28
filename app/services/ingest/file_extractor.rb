require "nokogiri"

module Ingest
  # Extracts plain text from an uploaded file. PDFs and DOCX are common for
  # investor letters; HTML/MD/TXT are trivial. We don't shell out to system
  # tools by default — install poppler-utils + pdftotext on the box if you
  # want PDF support, and the extractor will use it via Open3.
  class FileExtractor
    class ExtractionError < StandardError; end

    def self.extract(io:, filename:)
      new.extract(io: io, filename: filename)
    end

    def extract(io:, filename:)
      ext = File.extname(filename.to_s).downcase
      bytes = io.respond_to?(:read) ? io.read : io.to_s

      case ext
      when ".txt", ".md", ".text"
        bytes.force_encoding("UTF-8").scrub
      when ".html", ".htm"
        Nokogiri::HTML(bytes).text
      when ".pdf"
        extract_pdf(bytes)
      when ".docx"
        extract_docx(bytes)
      else
        raise ExtractionError, "unsupported file type: #{ext.inspect}"
      end
    end

    private

    def extract_pdf(bytes)
      require "open3"
      out, err, status = Open3.capture3("pdftotext", "-q", "-", "-")
      raise ExtractionError, "pdftotext not available: #{err}" unless status.success?
      out
    rescue Errno::ENOENT
      raise ExtractionError, "pdftotext binary not installed; `apt install poppler-utils`"
    end

    def extract_docx(bytes)
      # docx files are zip archives — the document body lives in
      # word/document.xml. Avoid pulling in `docx` gem; standard `Zip` is
      # part of stdlib via `rubyzip` (already a Rails transitive dep).
      require "zip"
      buf = ""
      Zip::File.open_buffer(bytes) do |zf|
        entry = zf.find_entry("word/document.xml")
        raise ExtractionError, "no word/document.xml in docx" unless entry
        xml = entry.get_input_stream.read
        buf = Nokogiri::XML(xml).text
      end
      buf
    rescue LoadError
      raise ExtractionError, "rubyzip gem not available; add it to the Gemfile"
    end
  end
end
