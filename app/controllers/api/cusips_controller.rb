# app/controllers/api/cusips_controller.rb
module Api
  class CusipsController < BaseController
    def show
      lookup = CompanyCusipLookup.find_by!(cusip: params[:cusip])
      render json: {
        cusip: lookup.cusip,
        symbol: lookup.symbol,
        issuer_name: lookup.issuer_name,
        class_title: lookup.class_title,
        shares_or_principal_amount_type: lookup.shares_or_principal_amount_type,
        holdings_count: lookup.holdings_count,
        # Optional enrichment fields — null if you don't have a price provider:
        market_cap: nil,
        price: nil,
        sector: nil,
        holders_count: lookup.holdings_count,
      }
    end

    def holders
      year     = params[:year]&.to_i     || latest_year
      quarter  = params[:quarter]&.to_i  || latest_quarter(year)
      page     = (params[:page]     || 1).to_i.clamp(1, 1000)
      per_page = (params[:per_page] || 50).to_i.clamp(1, 200)

      filings = ThirteenF.where(report_year: year, report_quarter: quarter)
      base = AggregateHolding.joins("INNER JOIN thirteen_fs ON aggregate_holdings.thirteen_f_id = thirteen_fs.id")
                             .where(cusip: params[:cusip], thirteen_f_id: filings.select(:id))
      total = base.count
      holders = base.select('aggregate_holdings.*, thirteen_fs.cik AS filer_cik, thirteen_fs.name AS filer_name, thirteen_fs.holdings_value_calculated AS filer_aum')
                    .order(value: :desc)
                    .offset((page - 1) * per_page)
                    .limit(per_page)

      render json: {
        data: holders.map { |h|
          {
            cik: h.filer_cik,
            name: h.filer_name,
            shares: h.shares_or_principal_amount.to_s,
            value: h.value.to_s,
            pct_of_filer: h.filer_aum.to_f.zero? ? 0 : (h.value.to_f / h.filer_aum.to_f * 100).round(3),
            # pct_of_company + delta_shares + delta_pct_qoq computed in a second query (omitted for brevity)
            pct_of_company: nil,
            delta_shares: '0',
            delta_pct_qoq: 0.0,
          }
        },
        total: total,
        page: page,
        per_page: per_page,
        year: year,
        quarter: quarter,
      }
    end

    def history
      counts = CusipQuarterlyFilingsCount.where(cusip: params[:cusip]).order(:report_year, :report_quarter)
      render json: counts.map { |c|
        # Aggregate shares + value across all filers in that period:
        filings = ThirteenF.where(report_year: c.report_year, report_quarter: c.report_quarter)
        rows = AggregateHolding.where(cusip: params[:cusip], thirteen_f_id: filings.select(:id))
        {
          q: "#{c.report_year}-Q#{c.report_quarter}",
          year: c.report_year,
          quarter: c.report_quarter,
          shares: rows.sum(:shares_or_principal_amount).to_s,
          value: rows.sum(:value).to_s,
          holders: c.filings_count,
        }
      }
    end

    private

    def latest_year
      ThirteenF.maximum(:report_year)
    end

    def latest_quarter(year)
      ThirteenF.where(report_year: year).maximum(:report_quarter)
    end
  end
end
