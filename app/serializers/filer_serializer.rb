# app/serializers/filer_serializer.rb
# Lightweight serializer for the directory list.
class FilerSerializer
  def initialize(filer)
    @filer = filer
  end

  def serializable_hash
    {
      cik: @filer.cik,
      name: @filer.name,
      city: @filer.city,
      state_or_country: @filer.state_or_country,
      most_recent_date_filed: @filer.most_recent_date_filed&.iso8601,
      filings_count: @filer.filings_count,
    }
  end
end
