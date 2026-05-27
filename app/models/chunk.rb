# Chunks carry pgvector (`dense_vec vector(96)`) and bytea columns that the
# default ActiveRecord adapter does not natively serialize. For v2 reads/writes
# go through raw SQL (or the pgvector gem once T-510 wires it in). Treat this
# model as a read-mostly handle to the row plus the assocs.
class Chunk < ApplicationRecord
  belongs_to :document
end
