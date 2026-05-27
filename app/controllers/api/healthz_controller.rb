# app/controllers/api/healthz_controller.rb
module Api
  class HealthzController < BaseController
    def show
      last_filing = ThirteenF.where.not(xml_data_fetched_at: nil).maximum(:xml_data_fetched_at)
      render json: {
        ok: true,
        db: ActiveRecord::Base.connection.active?,
        edgar_last_sync: last_filing&.iso8601,
        colbert: colbert_health,
        build: ENV['BUILD_SHA'] || 'dev',
      }
    end

    private

    def colbert_health
      h = ColbertClient.health
      { ok: true, model: h['model'], dim: h['dim'], device: h['device'] }
    rescue ColbertClient::Error => e
      { ok: false, error: e.message }
    end
  end
end
