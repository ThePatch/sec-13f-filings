# app/controllers/api/healthz_controller.rb
module Api
  class HealthzController < BaseController
    def show
      last_filing = ThirteenF.where.not(xml_data_fetched_at: nil).maximum(:xml_data_fetched_at)
      render json: {
        ok: true,
        db: ActiveRecord::Base.connection.active?,
        edgar_last_sync: last_filing&.iso8601,
        build: ENV['BUILD_SHA'] || 'dev',
      }
    end
  end
end
