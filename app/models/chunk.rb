# The dense_vec / embedding columns are pgvector vector(N). The `pgvector` gem
# (loaded via Bundler) registers the column adapter so reads/writes round-trip
# as Ruby Arrays. KNN queries use raw `<=>` SQL with parameterized vectors
# (see Retrieval::HybridRetriever#pgvector_first_pass).
class Chunk < ApplicationRecord
  belongs_to :document
end
