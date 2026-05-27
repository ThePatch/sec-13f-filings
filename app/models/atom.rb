class Atom < ApplicationRecord
  belongs_to :company, optional: true
  belongs_to :chunk, optional: true
  belongs_to :document, optional: true
  has_many :atom_outcomes, dependent: :destroy
end
