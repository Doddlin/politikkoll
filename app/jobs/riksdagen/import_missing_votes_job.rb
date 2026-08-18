module Riksdagen
  # Steadily fills in vote data for betänkanden we already have metadata for
  # but haven't checked for voteringar yet — a small batch per run so it
  # grows coverage without hammering the API or blocking for long.
  #
  # Some betänkanden genuinely have no roll-call vote (adopted by
  # acclamation), so "checked" is tracked separately from "has votes" via
  # votes_checked_at — otherwise those would get re-selected forever.
  class ImportMissingVotesJob < ApplicationJob
    queue_as :default

    BATCH_SIZE = 3

    def perform(batch_size: BATCH_SIZE)
      candidates = Document.where(doktyp: "bet", votes_checked_at: nil)
        .order(:rm, :beteckning)
        .limit(batch_size)

      candidates.each do |document|
        Riksdagen::VoteImporter.call(rm: document.rm, bet: document.beteckning)
        document.update!(votes_checked_at: Time.current)
      rescue => e
        Rails.logger.error("[ImportMissingVotesJob] #{document.rm} #{document.beteckning} failed: #{e.message}")
      end
    end
  end
end
