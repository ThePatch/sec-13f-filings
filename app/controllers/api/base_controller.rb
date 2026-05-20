# app/controllers/api/base_controller.rb
module Api
  class BaseController < ApplicationController
    skip_before_action :verify_authenticity_token  # CSRF disabled for cookie+CORS API
    before_action      :set_default_format
    rescue_from ActiveRecord::RecordNotFound, with: :not_found
    rescue_from ActionController::ParameterMissing, with: :bad_request

    private

    def set_default_format
      request.format = :json
    end

    def session_id
      # Use cookie-based session.id (Rails 7 provides this) or generate a stable one.
      session.id&.to_s || cookies[:anon_id] ||= SecureRandom.uuid
    end

    def paginate(scope)
      page     = (params[:page] || 1).to_i.clamp(1, 1000)
      per_page = (params[:per_page] || 30).to_i.clamp(1, 100)
      total    = scope.count
      data     = scope.offset((page - 1) * per_page).limit(per_page)
      { data: data, total: total, page: page, per_page: per_page }
    end

    def render_paginated(scope, serializer:)
      result = paginate(scope)
      render json: {
        data: result[:data].map { |r| serializer.new(r).serializable_hash },
        total: result[:total],
        page: result[:page],
        per_page: result[:per_page],
      }
    end

    def not_found(e)
      render json: { error: 'not_found', message: e.message }, status: :not_found
    end

    def bad_request(e)
      render json: { error: 'bad_request', message: e.message }, status: :bad_request
    end
  end
end
