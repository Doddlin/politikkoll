class ManifestoChunk < ApplicationRecord
  belongs_to :party
  has_neighbors :embedding

  validates :content, presence: true
  validates :election_year, presence: true
end
