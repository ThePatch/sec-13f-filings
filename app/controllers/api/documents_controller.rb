# POST /api/documents
#   multipart/form-data
#     file:         the uploaded file (PDF, DOCX, HTML, TXT, MD)
#     company_cusip: optional 9-char CUSIP to attach to a Company
#     doc_type:     one of earnings_call | news | sec_8k | sec_10q | ir_press |
#                   letter | sec_other (defaults to "letter")
#     title:        optional human label
#
# Stores the document, enqueues ProcessDocumentJob, returns the new id.
require "digest"

module Api
  class DocumentsController < BaseController
    def create
      file = params[:file]
      return bad_request("file missing") unless file.respond_to?(:original_filename)

      text = Ingest::FileExtractor.extract(io: file, filename: file.original_filename)
      return bad_request("could not extract text") if text.to_s.strip.empty?

      cusip   = params[:company_cusip].to_s
      company = cusip.present? ? Company.find_by(cusip: cusip) : nil
      title   = params[:title].presence || file.original_filename

      doc = Document.create!(
        company_id:    company&.id,
        source:        "manual",
        source_ref:    "upload:#{session_id}:#{SecureRandom.hex(6)}",
        doc_type:      params[:doc_type].presence || "letter",
        title:         title,
        authors:       Array(params[:authors]).compact,
        published_at:  Time.current,
        raw_text:      text,
        word_count:    text.split.size,
        content_hash:  Digest::SHA256.hexdigest(text),
        metadata:      { upload: { session: session_id, filename: file.original_filename } },
      )
      ProcessDocumentJob.perform_later(doc.id)

      render json: { id: doc.id, status: "queued", doc_type: doc.doc_type, title: doc.title }, status: :created
    rescue Ingest::FileExtractor::ExtractionError => e
      bad_request("extraction failed: #{e.message}")
    end

    private

    def bad_request(msg)
      render json: { error: "bad_request", message: msg }, status: :bad_request
    end
  end
end
