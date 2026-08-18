module Insights
  # Ranks members by how often they were recorded present (any ballot other
  # than Frånvarande) across every imported vote. Only members with records
  # for at least MIN_COVERAGE of all imported votes are ranked — Riksdagen's
  # data includes many ersättare (substitutes) who sat in for a handful of
  # votes and would otherwise show a meaningless 0% or 100%.
  class AttendanceLeaderboard
    Row = Struct.new(:member, :party_code, :total, :present, :rate, keyword_init: true)

    MIN_COVERAGE = 0.9

    def self.call = new.call

    def call
      total_votes = Vote.count
      return [] if total_votes.zero?

      min_records = (total_votes * MIN_COVERAGE).floor
      ballot_tally = VoteRecord.group(:member_id, :ballot).count
      party_tally = VoteRecord.group(:member_id, :party_code).count

      by_member_ballot = ballot_tally.group_by { |(member_id, _ballot), _count| member_id }
      by_member_party = party_tally.group_by { |(member_id, _party), _count| member_id }
      members = Member.where(id: by_member_ballot.keys).index_by(&:id)

      by_member_ballot.filter_map do |member_id, entries|
        counts = entries.to_h { |(_member, ballot), count| [ ballot, count ] }
        total = counts.values.sum
        next if total < min_records

        present = total - counts["franvarande"].to_i
        dominant_party = by_member_party[member_id].max_by { |(_member, _party), count| count }
        party_code = dominant_party.first.last

        Row.new(
          member: members[member_id],
          party_code: party_code,
          total: total,
          present: present,
          rate: present.to_f / total
        )
      end
    end
  end
end
