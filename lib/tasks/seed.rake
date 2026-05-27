namespace :db do
  desc "Seed companies from cusip_symbol_mappings. Idempotent (upsert on cusip)."
  task seed_companies_from_mappings: :environment do
    inserted = updated = skipped = 0

    CusipSymbolMapping.where.not(symbol: nil).find_each(batch_size: 500) do |mapping|
      cusip = mapping.cusip.to_s.strip
      if cusip.length != 9
        skipped += 1
        next
      end

      company = Company.find_by(cusip: cusip)
      attrs = {
        cusip:    cusip,
        ticker:   mapping.symbol.presence&.strip,
        cik:      mapping.cik.presence&.strip,
        name:     mapping.name.presence&.strip || mapping.symbol.to_s,
        exchange: mapping.exchange.presence&.strip,
      }

      if company.nil?
        Company.create!(attrs)
        inserted += 1
      else
        company.update!(attrs.compact)
        updated += 1
      end
    end

    puts "db:seed_companies_from_mappings"
    puts "  inserted: #{inserted}"
    puts "  updated:  #{updated}"
    puts "  skipped:  #{skipped}"
    puts "  total companies now: #{Company.count}"
  end
end
