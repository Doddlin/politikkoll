class InsightsController < ApplicationController
  LEADERBOARD_SIZE = 10

  def show
    rows = Insights::AttendanceLeaderboard.call
    @total_votes = Vote.count
    @most_present = rows.sort_by { |r| [ -r.rate, r.member.last_name ] }.first(LEADERBOARD_SIZE)
    @least_present = rows.sort_by { |r| [ r.rate, r.member.last_name ] }.first(LEADERBOARD_SIZE)
    @parties_by_code = Party.all.index_by(&:code)
  end
end
