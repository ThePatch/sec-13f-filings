# GET /api/atoms/:id — resolves a [a:N] citation back to its content + source
# chunk/document metadata. Increments access_count on read (a successful pull
# from a citation counts as a retrieval).
module Api
  class AtomsController < BaseController
    def show
      atom = Atom.find_by(id: params[:id])
      return render(json: { error: 'not_found' }, status: :not_found) unless atom

      doc = atom.document
      chunk = atom.chunk
      render json: {
        id:                 atom.id,
        content:            atom.content,
        source_quote:       atom.source_quote,
        profile:            atom.profile,
        stream:             atom.stream,
        state:              atom.state,
        stability:          atom.stability.to_f,
        access_count:       atom.access_count,
        topics:             atom.topics,
        last_accessed_at:   atom.last_accessed_at&.iso8601,
        chunk: chunk && { id: chunk.id, text: chunk.text.slice(0, 500) },
        document: doc && {
          id:           doc.id,
          doc_type:     doc.doc_type,
          title:        doc.title,
          published_at: doc.published_at&.iso8601,
          company_id:   doc.company_id,
        },
      }
    end
  end
end
