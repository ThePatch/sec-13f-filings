class Atom < ApplicationRecord
  belongs_to :company, optional: true
  belongs_to :chunk, optional: true
  belongs_to :document, optional: true
  has_many :atom_outcomes, dependent: :destroy

  # ACT-R stability is unit-less. Convert to ~hours of half-life: default
  # stability = 1.0 corresponds to a 168-hour (1 week) half-life. Used by
  # Atoms::DecayJob to compute current retrievability.
  def stability_hours
    MSAM_CONFIG.dig(:activation, :recency_half_life_hours).to_f * stability.to_f
  end
end
