module Api
  class MappingsController < BaseController
    def index
      scope = CusipSymbolMapping.all

      if params[:q].present?
        q = "%#{params[:q].downcase}%"
        scope = scope.where("lower(cusip) LIKE :q OR lower(symbol) LIKE :q OR lower(name) LIKE :q", q: q)
      end

      if params[:source].present? && params[:source] != 'all'
        scope = scope.where(source: params[:source])
      end

      scope = scope.order(:cusip)
      render_paginated(scope, serializer: CusipSymbolMappingSerializer)
    end

    def show
      m = CusipSymbolMapping.find_by!(cusip: params[:cusip])
      render json: CusipSymbolMappingSerializer.new(m).serializable_hash
    end

    def create
      m = CusipSymbolMapping.new(mapping_params.merge(source: 'manual', verified_at: Time.current))
      m.save!
      render json: CusipSymbolMappingSerializer.new(m).serializable_hash, status: :created
    end

    def update
      m = CusipSymbolMapping.find_by!(cusip: params[:cusip])
      m.update!(mapping_params)
      render json: CusipSymbolMappingSerializer.new(m).serializable_hash
    end

    def destroy
      m = CusipSymbolMapping.find_by!(cusip: params[:cusip])
      m.update!(source: 'unresolved', symbol: nil, confidence: 0, verified_at: nil)
      head :no_content
    end

    def sources
      stats = CusipSymbolMapping.group(:source).count
      max_per_source = CusipSymbolMapping.group(:source).maximum(:verified_at)

      registry = [
        { id: 'seed-yf',    name: 'OpenBB / yfinance seed',    kind: 'static',    status: 'imported' },
        { id: 'sec-ticker', name: 'SEC company_tickers.json',  kind: 'auto',      status: 'syncing'  },
        { id: 'openfigi',   name: 'OpenFIGI batch lookup',     kind: 'on-demand', status: 'active'   },
        { id: 'manual',     name: 'Manual entries',            kind: 'manual',    status: 'open'     },
        { id: 'unresolved', name: 'Unresolved',                kind: 'system',    status: 'queue'    },
      ]
      render json: registry.map { |r|
        r.merge(count: stats[r[:id]] || 0, last_synced_at: max_per_source[r[:id]]&.iso8601)
      }
    end

    # POST /api/mappings/sync/sec
    def sync_sec
      result = SecTickerSync.new.call
      render json: result
    end

    # POST /api/mappings/sync/openfigi
    def sync_openfigi
      result = OpenFigiResolver.new.resolve_unresolved!
      render json: result
    end

    # POST /api/mappings/sync/yfinance
    def sync_yfinance
      result = YfinanceSeed.new.call
      render json: result
    end

    private

    def mapping_params
      params.permit(:cusip, :symbol, :name, :exchange, :cik)
    end
  end
end
