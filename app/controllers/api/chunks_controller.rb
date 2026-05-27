# GET /api/chunks/:id — resolves a [c:N] citation back to its source text +
# parent document metadata, for the frontend's evidence drawer (T-605).
module Api
  class ChunksController < BaseController
    def show
      chunk = Chunk.find_by(id: params[:id])
      return render(json: { error: 'not_found' }, status: :not_found) unless chunk

      doc = chunk.document
      render json: {
        id:           chunk.id,
        ordinal:      chunk.ordinal,
        text:         chunk.text,
        token_count:  chunk.token_count,
        speaker:      chunk.speaker,
        section:      chunk.section,
        document: doc && {
          id:           doc.id,
          doc_type:     doc.doc_type,
          source:       doc.source,
          source_ref:   doc.source_ref,
          title:        doc.title,
          authors:      doc.authors,
          published_at: doc.published_at&.iso8601,
          raw_url:      doc.raw_url,
          company_id:   doc.company_id,
        },
      }
    end
  end
end
