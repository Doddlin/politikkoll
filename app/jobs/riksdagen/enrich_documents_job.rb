module Riksdagen
  # Steadily grows semantic search coverage: picks whatever documents (any
  # doktyp) don't have full text yet, fetches it, and embeds them. A small
  # batch per run — this is meant to run on a schedule and fill in over time,
  # not to blast through everything at once.
  class EnrichDocumentsJob < ApplicationJob
    queue_as :default

    BATCH_SIZE = 20

    def perform(batch_size: BATCH_SIZE)
      # Same riksmöte span DocumentImporter imports (START_RIKSMOTE through
      # current) — kept as one source of truth so this can't drift into
      # covering a different range than what's actually been imported.
      documents = Document.where(full_text: nil, rm: DocumentImporter.recent_riksmoten)
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
