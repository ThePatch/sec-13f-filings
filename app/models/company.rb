class Company < ApplicationRecord
  has_many :documents, dependent: :destroy
  has_many :atoms, dependent: :nullify

  validates :cusip, presence: true, uniqueness: true, length: { is: 9 }
  validates :name, presence: true
end
