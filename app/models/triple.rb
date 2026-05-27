class Triple < ApplicationRecord
  belongs_to :source_atom, class_name: "Atom", optional: true

  scope :currently_valid, -> { where(valid_until: nil) }
end
