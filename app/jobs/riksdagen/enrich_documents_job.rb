module Riksdagen
  # Steadily grows semantic search coverage: picks whatever documents (any
  # doktyp) don't have full text yet, fetches it, and embeds them. A small
  # batch per run — this is meant to run on a schedule and fill in over time,
  # not to blast through everything at once.
  class EnrichDocumentsJob < ApplicationJob
    queue_as :default

    BATCH_SIZE = 20

    # Two election terms back — old enough to compare "did they flip after
    # the last two elections," recent enough to stay relevant to current
    # politics. A rolling window (recomputed on every run), not a fixed
    # date, so it never needs manual updating as time passes. Document
    # import itself is a manual, rake-task-driven process (nothing walks
    # backward into old riksmöten on its own) — this is the guardrail for
    # if/when that ever changes, so full-text fetching and embedding (the
    # real ongoing cost) never silently balloon to cover low-relevance
    # history. Older documents still exist and are browsable, just not
    # enriched — bare metadata plus a link to the original source.
    RELEVANCE_WINDOW = 8.years

    def perform(batch_size: BATCH_SIZE)
      documents = Document.where(full_text: nil)
        .where(published_at: RELEVANCE_WINDOW.ago..)
        .limit(batch_size)
        .to_a
      return if documents.empty?

      fetched = documents.select { |document| fetch_full_text(document) }
      to_embed = fetched.select { |d| d.full_text.present? }

      Embeddings::DocumentEmbedder.call(to_embed) if to_embed.any?
    end

    private

    def fetch_full_text(document)
      Riksdagen::FullTextFetcher.call(document)
    rescue Riksdagen::FullTextFetcher::Error => e
      Rails.logger.warn("[EnrichDocumentsJob] full text failed for #{document.dok_id}: #{e.message}")
      # Mark as tried so a permanently-failing document doesn't get re-picked
      # by every future run.
      document.update!(full_text: "")
      false
    end
  end
end
