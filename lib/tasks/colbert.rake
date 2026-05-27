namespace :colbert do
  desc "End-to-end smoke test: embed → store → score → cleanup. Times each step."
  task smoke_test: :environment do
    require 'base64'
    require 'benchmark'

    timings = {}
    doc_id = chunk_id = nil

    begin
      timings[:create_document] = Benchmark.realtime do
        doc = Document.create!(
          doc_type: 'sec_8k',
          source: 'manual',
          source_ref: "colbert-smoke-#{Time.current.to_i}",
          title: 'ColBERT smoke test',
          published_at: Time.current,
          content_hash: SecureRandom.hex(8),
          raw_text: 'Apple beat EPS in Q3 2025.',
        )
        doc_id = doc.id
      end

      embed_result = nil
      timings[:embed_chunk] = Benchmark.realtime do
        embed_result = ColbertClient.embed_chunk(text: 'Apple beat EPS in Q3 2025.')
      end

      timings[:insert_chunk] = Benchmark.realtime do
        conn = ActiveRecord::Base.connection
        dense_literal = Pgvector.encode(embed_result[:dense_vec])
        blob_hex   = Base64.decode64(embed_result[:colbert_blob_b64]).unpack1('H*')
        scales_hex = Base64.decode64(embed_result[:colbert_scales_b64]).unpack1('H*')
        sql = <<~SQL
          INSERT INTO chunks (
            document_id, ordinal, text, token_count, start_char, end_char,
            dense_vec, colbert_blob, colbert_scales, colbert_dim, colbert_tokens
          ) VALUES (
            #{conn.quote(doc_id)},
            0,
            #{conn.quote('Apple beat EPS in Q3 2025.')},
            #{embed_result[:token_count].to_i},
            0,
            25,
            #{conn.quote(dense_literal)}::vector,
            decode(#{conn.quote(blob_hex)}, 'hex'),
            decode(#{conn.quote(scales_hex)}, 'hex'),
            #{embed_result[:colbert_dim].to_i},
            #{embed_result[:token_count].to_i}
          )
          RETURNING id
        SQL
        chunk_id = conn.exec_query(sql, 'colbert-smoke').rows.first.first
      end

      score_result = nil
      timings[:score] = Benchmark.realtime do
        score_result = ColbertClient.score(
          query: 'Apple earnings',
          candidates: [{
            id: chunk_id,
            blob_b64: embed_result[:colbert_blob_b64],
            scales_b64: embed_result[:colbert_scales_b64],
            dim: embed_result[:colbert_dim],
            num_tokens: embed_result[:token_count],
          }],
          top_k: 1,
        )
      end

      top = score_result[:results].first
      raise "expected score > 0, got #{top.inspect}" unless top && top[:score].to_f > 0

      puts "\nColBERT smoke test — OK"
      puts "  document_id   : #{doc_id}"
      puts "  chunk_id      : #{chunk_id}"
      puts "  embed encode_ms (sidecar self-report): #{embed_result[:encode_ms].to_f.round(1)}"
      puts "  score   score_ms (sidecar self-report): #{score_result[:score_ms].to_f.round(1)}"
      puts "  top score (chunk_id=#{top[:chunk_id]}): #{top[:score].round(3)}"
      puts
      puts "Step timings (Rails-side, includes HTTP and DB):"
      timings.each { |step, sec| puts "  %-18s %7.1f ms" % [step, sec * 1000] }

      slow = timings.select { |_, sec| sec > 5.0 }
      unless slow.empty?
        puts
        puts "WARNING: steps exceeded 5s threshold — record in BENCHMARKS.md:"
        slow.each { |step, sec| puts "  #{step}: #{(sec * 1000).round(1)} ms" }
      end
    ensure
      if chunk_id
        ActiveRecord::Base.connection.exec_delete("DELETE FROM chunks WHERE id = #{chunk_id.to_i}", 'colbert-smoke')
      end
      Document.where(id: doc_id).delete_all if doc_id
    end
  end
end
