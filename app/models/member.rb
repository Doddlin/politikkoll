class Member < ApplicationRecord
  has_many :vote_records, dependent: :destroy

  validates :intressent_id, presence: true, uniqueness: true

  def full_name
    "#{first_name} #{last_name}"
  end
end
