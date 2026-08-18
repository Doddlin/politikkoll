class VoteRecord < ApplicationRecord
  belongs_to :vote
  belongs_to :member

  enum :ballot, { ja: 0, nej: 1, avstar: 2, franvarande: 3 }

  validates :party_code, presence: true
  validates :member_id, uniqueness: { scope: :vote_id }
end
