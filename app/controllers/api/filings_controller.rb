# app/controllers/api/filings_controller.rb
module Api
  class FilingsController < BaseController
    def show
      f = ThirteenF.find(params[:id])
      render json: f.as_json(except: %i[primary_doc_xml info_table_xml])
    end

    def holdings
      h = Holding.where(thirteen_f_id: params[:id])
      render json: h
    end

    def aggregate_holdings
      a = AggregateHolding.where(thirteen_f_id: params[:id]).order(value: :desc)
      render json: a
    end

    def compare
      before = ThirteenF.find(params[:other_id])  # historically older
      after  = ThirteenF.find(params[:id])         # the current one

      before_holdings = AggregateHolding.where(thirteen_f_id: before.id).index_by(&:cusip)
      after_holdings  = AggregateHolding.where(thirteen_f_id: after.id).index_by(&:cusip)

      all_cusips = (before_holdings.keys + after_holdings.keys).uniq
      symbol_lookup = CompanyCusipLookup.where(cusip: all_cusips).index_by(&:cusip)

      total_after = after.holdings_value_calculated.to_f
      total_before = before.holdings_value_calculated.to_f

      rows = all_cusips.map do |cusip|
        b = before_holdings[cusip]
        a = after_holdings[cusip]
        co = symbol_lookup[cusip]

        kind =
          if b.nil? && a then 'new'
          elsif b && a.nil? then 'exited'
          elsif a.shares_or_principal_amount > b.shares_or_principal_amount then 'added'
          elsif a.shares_or_principal_amount < b.shares_or_principal_amount then 'reduced'
          else 'unchanged'
          end

        before_block = b && {
          shares: b.shares_or_principal_amount.to_s,
          value: b.value.to_s,
          pct: total_before.zero? ? 0 : (b.value.to_f / total_before * 100).round(2),
        }
        after_block = a && {
          shares: a.shares_or_principal_amount.to_s,
          value: a.value.to_s,
          pct: total_after.zero? ? 0 : (a.value.to_f / total_after * 100).round(2),
        }

        delta_shares = (a&.shares_or_principal_amount || 0) - (b&.shares_or_principal_amount || 0)
        delta_value  = (a&.value || 0) - (b&.value || 0)

        {
          cusip: cusip,
          symbol: co&.symbol,
          issuer_name: (a || b).issuer_name,
          kind: kind,
          before: before_block,
          after: after_block,
          delta_shares: delta_shares.to_s,
          delta_value: delta_value.to_s,
          delta_pct: b&.value.to_f > 0 ? ((delta_value / b.value.to_f) * 100).round(2) : 0,
        }
      end

      summary = rows.group_by { |r| r[:kind] }.transform_values(&:count)
      summary['unchanged'] ||= 0

      render json: {
        before: before.as_json(except: %i[primary_doc_xml info_table_xml]),
        after:  after.as_json(except: %i[primary_doc_xml info_table_xml]),
        summary: {
          new_positions: summary['new'] || 0,
          exits:         summary['exited'] || 0,
          added:         summary['added'] || 0,
          reduced:       summary['reduced'] || 0,
          unchanged:     summary['unchanged'] || 0,
          net_value_change: (total_after - total_before).to_s,
        },
        rows: rows.sort_by { |r| -(r[:after]&.dig(:value).to_f || r[:before]&.dig(:value).to_f) },
      }
    end
  end
end
