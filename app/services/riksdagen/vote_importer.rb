module Riksdagen
  # Pulls roll-call voting data from data.riksdagen.se's open API and upserts
  # it into parties/members/votes/vote_records. Safe to re-run: every write is
  # keyed on the source's own stable IDs (votering_id, intressent_id), so
  # re-importing a riksmöte just confirms rather than duplicates.
  class VoteImporter
    BASE_URL = "https://data.riksdagen.se/voteringlista/"
    # Large enough that a single betänkande's full roll call (~349 members
    # per votering) fits on one page even for a busy committee report with
    # dozens of voteringar — data.riksdagen.se's pagination is unreliable
    # past the first page (it can return the same rows again instead of
    # advancing), so page 1 covering everything sidesteps that entirely for
    # our per-betänkande import pattern.
    PAGE_SIZE = 15_000
    # Safety net for the rare case that isn't enough — no real betänkande
    # needs this many pages; this exists purely to guarantee termination.
    MAX_PAGES = 20

    BALLOT_MAP = {
      "Ja" => "ja",
      "Nej" => "nej",
      "Avstår" => "avstar",
      "Frånvarande" => "franvarande"
    }.freeze

    def self.call(...)
      new(...).call
    end

    # rm:  riksmöte, e.g. "2023/24"
    # bet: optional beteckning filter, e.g. "FiU1" — omit to import the whole riksmöte
    def initialize(rm:, bet: nil, page_size: PAGE_SIZE)
      @rm = rm
      @bet = bet
      @page_size = page_size
      @connection = Faraday.new(url: BASE_URL) do |f|
        f.request :retry, max: 3, interval: 1
        f.response :raise_error
      end
    end

    def call
      stats = { pages: 0, rows: 0, votes: 0, vote_records: 0 }

      each_page do |rows|
        stats[:pages] += 1
        stats[:rows] += rows.size

        rows.each { |row| import_row(row, stats) }
      end

      stats
    end

    private

    def each_page
      page = 1
      seen_votering_ids = Set.new

      loop do
        rows = fetch_page(page)
        break if rows.empty?

        page_votering_ids = rows.map { |r| r["votering_id"] }.to_set
        break if page > 1 && page_votering_ids.subset?(seen_votering_ids)

        seen_votering_ids.merge(page_votering_ids)
        yield rows

        break if rows.size < @page_size || page >= MAX_PAGES

        page += 1
      end
    end

    def fetch_page(page)
      params = { rm: @rm, utformat: "json", sz: @page_size, p: page }
      params[:bet] = @bet if @bet.present?

      response = @connection.get("", params)
      body = JSON.parse(response.body)
      raw = body.dig("voteringlista", "votering")

      case raw
      when Array then raw
      when Hash then [ raw ]
      else []
      end
    end

    def import_row(row, stats)
      party = Party.find_or_create_by!(code: row["parti"]) do |p|
        p.name = row["parti"]
      end

      member = Member.find_or_initialize_by(intressent_id: row["intressent_id"])
      member.first_name = row["fornamn"]
      member.last_name = row["efternamn"]
      member.save! if member.changed?

      vote = Vote.find_or_initialize_by(votering_id: row["votering_id"])
      if vote.new_record?
        vote.rm = row["rm"]
        vote.beteckning = row["beteckning"]
        vote.punkt = row["punkt"]
        vote.dok_id = row["dok_id"].presence
        vote.avser = row["avser"]
        vote.save!
        stats[:votes] += 1
      end

      record = VoteRecord.find_or_initialize_by(vote: vote, member: member)
      record.party_code = party.code
      record.constituency = row["valkrets"]
      record.ballot = BALLOT_MAP.fetch(row["rost"], "franvarande")
      if record.changed?
        record.save!
        stats[:vote_records] += 1
      end
    end
  end
end
