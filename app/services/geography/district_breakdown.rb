module Geography
  # Aggregates vote_records by constituency (valkrets), either for a single
  # vote or across every vote tied to documents in a topic area (via
  # Document#organ — the same "high certainty" categorization used for
  # document browsing). support_rate is Ja's share of decisive votes (Ja +
  # Nej), which is what "how did this district come down on this" means —
  # Avstår/Frånvarande aren't a stance either way. party_breakdown carries
  # the same counts split by party, per ballot, for the hover breakdown.
  class DistrictBreakdown
    Row = Struct.new(:constituency, :ja, :nej, :avstar, :franvarande, :support_rate, :party_breakdown, keyword_init: true) do
      def total = ja + nej + avstar + franvarande
    end

    def self.call(...) = new(...).call

    def initialize(area: nil, votering_id: nil)
      @area = area
      @votering_id = votering_id
    end

    def call
      scope = VoteRecord.joins(:vote)
      scope = scope.where(votes: { votering_id: @votering_id }) if @votering_id.present?
      scope = scope.where(votes: { dok_id: Document.where(organ: @area).select(:dok_id) }) if @area.present?

      tally = scope.group(:constituency, :ballot, :party_code).count
      by_constituency = tally.group_by { |(constituency, _ballot, _party), _count| constituency }

      by_constituency.map do |constituency, entries|
        ballot_counts = Hash.new(0)
        party_breakdown = Hash.new { |h, k| h[k] = [] }

        entries.each do |(_constituency, ballot, party), count|
          ballot_counts[ballot] += count
          party_breakdown[ballot] << [ party, count ]
        end
        party_breakdown.each_value { |list| list.sort_by! { |(_party, count)| -count } }

        ja = ballot_counts["ja"]
        nej = ballot_counts["nej"]
        decisive = ja + nej

        Row.new(
          constituency: constituency,
          ja: ja, nej: nej,
          avstar: ballot_counts["avstar"],
          franvarande: ballot_counts["franvarande"],
          support_rate: decisive.positive? ? ja.to_f / decisive : nil,
          party_breakdown: party_breakdown
        )
      end.sort_by { |r| r.support_rate.nil? ? 1 : -r.support_rate }
    end
  end
end
