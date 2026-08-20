module Riksdagen
  # Pulls document metadata (betänkanden, motioner, ...) from data.riksdagen.se's
  # dokumentlista endpoint. Full text isn't fetched here — that's a separate,
  # heavier pass once embeddings/semantic search are wired up. For now this
  # just gets titles and the beteckning that bridges to Vote records, which is
  # enough to power keyword search.
  class DocumentImporter
    BASE_URL = "https://data.riksdagen.se/dokumentlista/"
    PAGE_SIZE = 500
    PARTY_PATTERN = /\(([A-ZÅÄÖ]+)\)\s*\z/

    def self.call(...)
      new(...).call
    end

    # The fixed lower bound of what we import — deliberately not a rolling
    # window, so the covered span only ever grows (never drifts backward or
    # loses a riksmöte as years pass).
    START_RIKSMOTE = "2023/24"

    # Every riksmöte from START_RIKSMOTE through the current one, oldest
    # first — e.g. ["2023/24", "2024/25", "2025/26"] today. A riksmöte runs
    # September through June, so before September the "current" one is
    # still last year's. This is the one source of truth for "what span do
    # we cover" — Riksdagen::EnrichDocumentsJob filters by the same list
    # rather than keeping a separate date window, so the two can't drift
    # apart into a gap.
    def self.recent_riksmoten
      start_year = START_RIKSMOTE[0, 4].to_i
      today = Time.current
      end_year = today.month >= 9 ? today.year : today.year - 1
      (start_year..end_year).map { |y| "#{y}/#{(y + 1).to_s[-2..]}" }
    end

    # rm:     riksmöte, e.g. "2023/24"
    # doktyp: document type, e.g. "bet" (betänkande) or "mot" (motion)
    def initialize(rm:, doktyp:, page_size: PAGE_SIZE)
      @rm = rm
      @doktyp = doktyp
      @page_size = page_size
      @connection = Faraday.new(url: BASE_URL) do |f|
        # Faraday's retry default only covers timeouts — a plain ECONNRESET
        # (confirmed live: killed a full riksdagen:backfill_documents run
        # mid-way) isn't in that list unless named explicitly here.
        f.request :retry,
                  max: 3,
                  interval: 1,
                  backoff_factor: 2,
                  exceptions: [
                    Faraday::ConnectionFailed,
                    Faraday::TimeoutError,
                    Errno::ECONNRESET,
                    Errno::ETIMEDOUT
                  ]
        f.adapter Faraday.default_adapter
      end
    end

    def call
      stats = { pages: 0, rows: 0, created: 0, updated: 0 }
      total_pages = 1
      page = 1

      while page <= total_pages
        body = fetch_page(page)
        total_pages = body["@sidor"].to_i
        rows = Array(body["dokument"])

        stats[:pages] += 1
        stats[:rows] += rows.size
        rows.each { |row| import_row(row, stats) }

        page += 1
      end

      stats
    end

    private

    def fetch_page(page)
      response = @connection.get("", rm: @rm, doktyp: @doktyp, utformat: "json", sz: @page_size, p: page)
      JSON.parse(response.body.force_encoding(Encoding::UTF_8))["dokumentlista"]
    end

    def import_row(row, stats)
      next_dok_id = row["dok_id"]
      return if next_dok_id.blank?

      document = Document.find_or_initialize_by(dok_id: next_dok_id)
      new_record = document.new_record?

      document.rm = row["rm"]
      document.doktyp = row["doktyp"]
      document.subtyp = row["subtyp"]
      document.beteckning = row["beteckning"]
      document.titel = row["titel"]
      document.authors = row["undertitel"].presence
      document.party_code = row["undertitel"].to_s[PARTY_PATTERN, 1]
      document.organ = row["organ"]
      document.published_at = row["datum"].presence
      document.source_url = "https://data.riksdagen.se/dokument/#{next_dok_id}"

      return unless document.changed?

      document.save!
      stats[new_record ? :created : :updated] += 1
    end
  end
end
