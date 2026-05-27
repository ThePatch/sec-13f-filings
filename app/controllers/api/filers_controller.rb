# app/controllers/api/filers_controller.rb
module Api
  class FilersController < BaseController
    # GET /api/filers/by_ciks?ciks=CIK1,CIK2,...  — minimal {cik, name} batch lookup
    # for the WatchlistScreen avatar row. Capped at 200 to keep the response small.
    def by_ciks
      ciks = Array(params[:ciks].to_s.split(',')).map(&:strip).reject(&:blank?).first(200)
      return render(json: []) if ciks.empty?

      rows = ThirteenFFiler.where(cik: ciks).pluck(:cik, :name)
      render json: rows.map { |cik, name| { cik: cik, name: name } }
    end

    def index
      scope = ThirteenFFiler.all

      if params[:q].present?
        # Uses the pg_trgm index already in the schema
        scope = scope.where("lower(name) LIKE ?", "%#{params[:q].downcase}%")
      end

      scope = case params[:sort]
              when 'aum'        then scope # AUM is denormalized via subquery — see below
              when 'qoq'        then scope
              when 'positions'  then scope
              when 'name'       then scope.order(Arel.sql('lower(name) asc'))
              else                   scope.order(most_recent_date_filed: :desc)
              end

      render_paginated(scope, serializer: FilerSerializer)
    end

    def show
      @filer = ThirteenFFiler.find_by!(cik: params[:cik])
      latest = ThirteenF.where(cik: @filer.cik).order(date_filed: :desc).first

      render json: FilerDetailSerializer.new(@filer, params: { latest: latest }).serializable_hash
    end

    def filings
      filings = ThirteenF.where(cik: params[:cik]).order(date_filed: :desc)
      render json: filings.as_json(only: %i[id external_id form_type date_filed report_date
                                            holdings_count_calculated holdings_value_calculated
                                            report_year report_quarter amendment_type])
    end

    def aum_history
      filings = ThirteenF.where(cik: params[:cik])
                         .where.not(report_year: nil)
                         .order(report_year: :asc, report_quarter: :asc)
      points = filings.map do |f|
        { q: "#{f.report_year}-Q#{f.report_quarter}", value: f.holdings_value_calculated.to_s }
      end
      render json: points
    end
  end
end
