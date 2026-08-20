class PagesController < ApplicationController
  def disclaimer
  end

  def how_it_works
  end

  def status
    riksmoten = Riksdagen::DocumentImporter.recent_riksmoten

    votes_count = Vote.group(:rm).count
    votes_latest = Vote.group(:rm).maximum(:voted_on)
    betankanden_count = Document.where(doktyp: "bet").group(:rm).count
    motioner_count = Document.where(doktyp: "mot").group(:rm).count
    documents_latest = Document.group(:rm).maximum(:published_at)

    @coverage = riksmoten.reverse.map do |rm|
      {
        rm: rm,
        votes: votes_count[rm] || 0,
        latest_vote: votes_latest[rm],
        betankanden: betankanden_count[rm] || 0,
        motioner: motioner_count[rm] || 0,
        latest_document: documents_latest[rm]
      }
    end

    manifesto_counts = ManifestoChunk.group(:party_id, :election_year).count
    parties_by_id = Party.where(id: manifesto_counts.keys.map(&:first)).index_by(&:id)
    @manifestos = manifesto_counts
      .map { |(party_id, year), count| { party: parties_by_id[party_id], election_year: year, chunks: count } }
      .sort_by { |m| [ -m[:election_year], m[:party]&.code.to_s ] }

    @totals = {
      documents: Document.count,
      votes: Vote.count,
      searchable: Document.where.not(embedding: nil).count + ManifestoChunk.where.not(embedding: nil).count,
      members: Member.count
    }
  end
end
