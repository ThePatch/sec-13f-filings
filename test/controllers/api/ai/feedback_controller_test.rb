require 'test_helper'

module Api
  module Ai
    class FeedbackControllerTest < ActionDispatch::IntegrationTest
      def setup
        @session_id = SecureRandom.uuid
        @doc = Document.create!(
          doc_type: "news", source: "test", source_ref: "fb-#{SecureRandom.hex(4)}",
          title: "x", published_at: Time.current,
          content_hash: SecureRandom.hex(8), raw_text: "x",
        )
        @atom = Atom.create!(
          document_id: @doc.id, content: "fb atom",
          content_hash: SecureRandom.hex(8), token_count: 5, stability: 1.0,
        )
        @atom2 = Atom.create!(
          document_id: @doc.id, content: "fb atom 2",
          content_hash: SecureRandom.hex(8), token_count: 5, stability: 1.0,
        )

        message_id = SecureRandom.uuid
        @message_id = message_id
        @convo = AiConversation.create!(
          session_id: @session_id,
          title: 't',
          messages: [{
            id: message_id, role: 'assistant', body: "answer",
            citations: [
              { type: 'atom',  id: @atom.id },
              { type: 'atom',  id: @atom2.id },
              { type: 'chunk', id: 1 },
            ],
          }],
        )

        cookies[:_session_id] = @session_id rescue nil
      end

      def teardown
        AtomOutcome.where(atom_id: [@atom.id, @atom2.id]).delete_all
        Atom.where(id: [@atom.id, @atom2.id]).delete_all
        AiConversation.where(id: @convo.id).delete_all
        Document.where(id: @doc.id).delete_all
      end

      test 'message_feedback records one AtomOutcome per cited atom' do
        Api::BaseController.any_instance.stubs(:session_id).returns(@session_id)
        post "/api/ai/messages/#{@message_id}/feedback",
             params: { signal: 1, reason: 'thumbs_up' }, as: :json
        assert_response :success
        body = JSON.parse(response.body)
        assert_equal 2, body['recorded']
        assert_equal 2, AtomOutcome.where(atom_id: [@atom.id, @atom2.id]).count
        assert_equal 'thumbs_up', AtomOutcome.where(atom_id: @atom.id).first.reason
      end

      test 'message_feedback rejects invalid signal' do
        Api::BaseController.any_instance.stubs(:session_id).returns(@session_id)
        post "/api/ai/messages/#{@message_id}/feedback", params: { signal: 7 }, as: :json
        assert_response :bad_request
      end

      test 'atom_correction stores correction text with -1 signal' do
        Api::BaseController.any_instance.stubs(:session_id).returns(@session_id)
        post "/api/ai/atoms/#{@atom.id}/correct",
             params: { correction: 'actually it was Q4 not Q3' }, as: :json
        assert_response :success
        outcome = AtomOutcome.where(atom_id: @atom.id).order(created_at: :desc).first
        assert_equal(-1.0, outcome.signal)
        assert_equal 'corrected', outcome.reason
        assert_equal 'actually it was Q4 not Q3', outcome.metadata['correction']
      end

      test 'atom_correction 404s on unknown atom' do
        Api::BaseController.any_instance.stubs(:session_id).returns(@session_id)
        post "/api/ai/atoms/99999999/correct", params: { correction: 'x' }, as: :json
        assert_response :not_found
      end
    end
  end
end
