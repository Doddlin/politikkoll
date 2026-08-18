class Vote < ApplicationRecord
  has_many :vote_records, dependent: :destroy

  validates :votering_id, presence: true, uniqueness: true

  def party_tally
    vote_records.group(:party_code, :ballot).count
  end

  # Renderable vote-board data: each party reduced to its dominant ballot
  # (parties mostly vote as a bloc) in a consistent left-to-right political
  # order. Shared by the chat answerer and the document detail page.
  def board
    tally = party_tally
    party_codes = tally.keys.map(&:first).uniq

    seats = Party.sort_codes(party_codes).map do |code|
      entries = tally.select { |(party, _ballot), _count| party == code }
      (_party, ballot), count = entries.max_by { |_, c| c }
      { party: code, ballot: ballot, count: count }
    end

    { beteckning: beteckning, rm: rm, punkt: punkt,
      source_url: "https://data.riksdagen.se/votering/#{votering_id}", seats: seats }
  end
end
