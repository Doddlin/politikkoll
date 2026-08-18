class ChatMessage < ApplicationRecord
  belongs_to :conversation

  enum :role, { user: "user", assistant: "assistant" }, validate: true

  validates :content, presence: true

  # sources/vote_boards are stored with symbol-ish keys in Ruby but come back
  # from jsonb as string keys — normalize on read so views don't have to care.
  def source_list
    sources.map { |s| { label: s["label"], url: s["url"] } }
  end

  def vote_board_list
    vote_boards.map do |b|
      {
        beteckning: b["beteckning"], rm: b["rm"], punkt: b["punkt"], source_url: b["source_url"],
        seats: b["seats"].map { |s| { party: s["party"], ballot: s["ballot"], count: s["count"] } }
      }
    end
  end
end
