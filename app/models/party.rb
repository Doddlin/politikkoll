class Party < ApplicationRecord
  has_many :manifesto_chunks, dependent: :destroy
  has_many :vote_records, foreign_key: :party_code, primary_key: :code, inverse_of: false

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true

  # Conventional left-to-right political ordering, used wherever parties are
  # displayed side by side (vote boards, comparisons).
  POLITICAL_ORDER = %w[V MP S C L KD M SD].freeze

  def self.sort_codes(codes)
    codes.sort_by { |code| POLITICAL_ORDER.index(code) || POLITICAL_ORDER.size }
  end
end
