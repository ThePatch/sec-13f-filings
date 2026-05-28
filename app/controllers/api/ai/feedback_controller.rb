# Thumbs up/down on AI messages → atom_outcomes rows that feed into the
# AtomScorer outcome term on subsequent retrievals.
#
# POST /api/ai/messages/:id/feedback   body: {signal: -1|+1, reason: "..."}
#   Records an outcome row per atom cited in the message.
#
# POST /api/ai/atoms/:id/correct       body: {correction: String}
#   Records a -1.0 signal with reason "corrected" and stores the user's
#   correction text in metadata.correction.
#
# Messages are stored as a JSONB array in `conversations.messages`. The
# `:id` here is the UUID embedded in each message envelope (set by
# Ai::Router#message_record). We resolve atom ids by scanning the most-
# recently-updated conversation in this session whose messages array
# contains a matching id; the citations are stored alongside the message
# body when the SPA persists conversations through T-606.
module Api
  module Ai
    class FeedbackController < Api::BaseController
      def message_feedback
        signal = params[:signal].to_f
        reason = params[:reason].to_s.presence || infer_reason(signal)
        return bad_request("signal must be -1 or +1") unless signal.abs == 1.0

        atom_ids = atoms_for_message(params[:id])
        return not_found("message_not_found_or_no_atom_citations") if atom_ids.empty?

        rows = atom_ids.map do |atom_id|
          {
            atom_id:    atom_id,
            session_id: session_id,
            signal:     signal,
            reason:     reason,
            metadata:   { message_id: params[:id] },
            created_at: Time.current,
          }
        end
        AtomOutcome.insert_all!(rows)

        render json: { ok: true, recorded: rows.size }
      end

      def atom_correction
        atom = Atom.find_by(id: params[:id])
        return not_found("atom_not_found") unless atom

        correction = params[:correction].to_s
        return bad_request("correction required") if correction.blank?

        AtomOutcome.create!(
          atom_id:    atom.id,
          session_id: session_id,
          signal:     -1.0,
          reason:     "corrected",
          metadata:   { correction: correction },
        )
        render json: { ok: true }
      end

      private

      def infer_reason(signal)
        signal > 0 ? "thumbs_up" : "thumbs_down"
      end

      # Walk recent conversations for this session and find the message UUID
      # in their messages JSONB. Returns [] if not found.
      def atoms_for_message(message_id)
        return [] if message_id.blank?
        AiConversation
          .where(session_id: session_id)
          .order(updated_at: :desc)
          .limit(20)
          .find_each do |convo|
            Array(convo.messages).each do |m|
              h = m.is_a?(Hash) ? m : m.to_h
              next unless (h["id"] || h[:id]).to_s == message_id.to_s
              cites = Array(h["citations"] || h[:citations])
              ids = cites.select { |c| (c["type"] || c[:type]) == "atom" }
                         .map { |c| (c["id"] || c[:id]).to_i }
              return ids
            end
          end
        []
      end

      def bad_request(msg)
        render json: { error: "bad_request", message: msg }, status: :bad_request
      end

      def not_found(code)
        render json: { error: code }, status: :not_found
      end
    end
  end
end
