# The Python ColBERT sidecar quantizes token embeddings with one scale per
# vector — needed to dequantize correctly on /score. The original v2 chunks
# schema stored colbert_blob but not the scales, leaving stored chunks unable
# to be re-ranked. Add the column.
class AddColbertScalesToChunks < ActiveRecord::Migration[6.1]
  def change
    add_column :chunks, :colbert_scales, :binary
    change_column_null :chunks, :colbert_scales, false, "''"
  end
end
