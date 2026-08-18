class Document < ApplicationRecord
  has_neighbors :embedding

  validates :dok_id, presence: true, uniqueness: true

  # Riksdagen's own committee assignment — administrative ground truth, not
  # a guess, so it doubles as a reliable topic-area taxonomy for browsing.
  AREAS = %w[FiU JuU SkU KU SoU CU TU NU SfU MJU UbU UU FöU KrU AU UFöU].freeze

  def to_param
    dok_id
  end
end
