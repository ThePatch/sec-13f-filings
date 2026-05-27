# Thin Ruby wrapper around the Python ColBERT sidecar (services/colbert/main.py).
# The sidecar runs FastAPI on 127.0.0.1:7400; this class translates Ruby calls
# into HTTP requests and unwraps the JSON.
#
# Sidecar contract — see handoff/v2/services/colbert/main.py for the source of
# truth. Three endpoints used here: /health, /embed_chunk, /score.
class ColbertClient
  include HTTParty

  class Error < StandardError; end

  base_uri ENV.fetch('COLBERT_URL', 'http://127.0.0.1:7400')
  default_timeout 30

  def self.health
    request(:get, '/health')
  end

  def self.embed_chunk(text:)
    body = request(:post, '/embed_chunk', body: { text: text })
    {
      dense_vec:           body.fetch('dense_vec'),
      colbert_blob_b64:    body.fetch('colbert_blob_b64'),
      colbert_scales_b64:  body.fetch('colbert_scales_b64'),
      colbert_dim:         body.fetch('colbert_dim'),
      token_count:         body.fetch('colbert_tokens'),
      encode_ms:           body.fetch('encode_ms'),
    }
  end

  def self.encode_query(text:)
    request(:post, '/encode_query', body: { text: text })
  end

  # candidates: [{id:, blob_b64:, scales_b64:, dim:, num_tokens:}, ...]
  def self.score(query:, candidates:, top_k: 8)
    body = request(:post, '/score', body: {
      query: query,
      candidates: candidates.map { |c| stringify_candidate(c) },
      top_k: top_k,
    })
    results = body.fetch('results').map do |r|
      { chunk_id: r.fetch('chunk_id'), score: r.fetch('score') }
    end
    { results: results, query_tokens: body['query_tokens'], score_ms: body['score_ms'] }
  end

  def self.request(method, path, body: nil)
    opts = { headers: { 'Content-Type' => 'application/json' } }
    opts[:body] = body.to_json if body

    response =
      case method
      when :get  then get(path, opts)
      when :post then post(path, opts)
      else raise ArgumentError, "unsupported method #{method.inspect}"
      end

    unless response.code.between?(200, 299)
      raise Error, "ColBERT sidecar returned #{response.code}: #{response.body}"
    end

    response.parsed_response
  rescue HTTParty::Error, Errno::ECONNREFUSED, SocketError, Net::OpenTimeout, Net::ReadTimeout => e
    raise Error, "ColBERT sidecar unreachable: #{e.class}: #{e.message}"
  end
  private_class_method :request

  def self.stringify_candidate(c)
    {
      id:         c[:id]         || c['id'],
      blob_b64:   c[:blob_b64]   || c['blob_b64'],
      scales_b64: c[:scales_b64] || c['scales_b64'],
      dim:        c[:dim]        || c['dim'],
      num_tokens: c[:num_tokens] || c['num_tokens'],
    }
  end
  private_class_method :stringify_candidate
end
