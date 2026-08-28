class ChatMessage < ApplicationRecord
  belongs_to :conversation

  enum :role, { user: "user", assistant: "assistant" }, validate: true
  # pending: an assistant turn whose answer is still being generated in the
  # background — content is nil until AnswerJob fills it in and broadcasts
  # the update. Regular user messages, and finished answers, are
  # "complete"; "failed" also carries content (a user-facing error string)
  # so a page reload shows the same error instead of an eternal thinking
  # bubble — it's a separate status purely so the view can style it as an
  # error rather than a normal answer.
  enum :status, { pending: "pending", complete: "complete", failed: "failed" }, validate: true

  validates :content, presence: true, unless: :pending?

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
