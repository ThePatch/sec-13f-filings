# app/serializers/cusip_symbol_mapping_serializer.rb
# Serializer for CusipSymbolMapping rows returned by Api::MappingsController.
class CusipSymbolMappingSerializer
  def initialize(mapping)
    @mapping = mapping
  end

  def serializable_hash
    {
      id: @mapping.id,
      cusip: @mapping.cusip,
      symbol: @mapping.symbol,
      name: @mapping.name,
      exchange: @mapping.exchange,
      cik: @mapping.cik,
      source: @mapping.source,
      confidence: @mapping.confidence,
      verified_at: @mapping.verified_at&.iso8601,
      created_at: @mapping.created_at&.iso8601,
      updated_at: @mapping.updated_at&.iso8601,
    }
  end
end
