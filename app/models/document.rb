class Document < ApplicationRecord
  belongs_to :company, optional: true
  has_many :chunks, dependent: :destroy
end
