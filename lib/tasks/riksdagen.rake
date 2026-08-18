namespace :riksdagen do
  desc "Import roll-call votes from data.riksdagen.se. Usage: rails riksdagen:import_votes RM=2023/24 [BET=FiU1]"
  task import_votes: :environment do
    rm = ENV.fetch("RM") { abort "Usage: rails riksdagen:import_votes RM=2023/24 [BET=FiU1]" }
    bet = ENV["BET"]

    puts "Importing votes for rm=#{rm}#{" bet=#{bet}" if bet}..."
    stats = Riksdagen::VoteImporter.call(rm: rm, bet: bet)
    puts "Done. Pages: #{stats[:pages]}, rows seen: #{stats[:rows]}, " \
         "new votes: #{stats[:votes]}, new/updated vote records: #{stats[:vote_records]}"
  end

  desc "Import document metadata from data.riksdagen.se. Usage: rails riksdagen:import_documents RM=2023/24 DOKTYP=bet"
  task import_documents: :environment do
    rm = ENV.fetch("RM") { abort "Usage: rails riksdagen:import_documents RM=2023/24 DOKTYP=bet" }
    doktyp = ENV.fetch("DOKTYP") { abort "Usage: rails riksdagen:import_documents RM=2023/24 DOKTYP=bet" }

    puts "Importing #{doktyp} documents for rm=#{rm}..."
    stats = Riksdagen::DocumentImporter.call(rm: rm, doktyp: doktyp)
    puts "Done. Pages: #{stats[:pages]}, rows seen: #{stats[:rows]}, " \
         "created: #{stats[:created]}, updated: #{stats[:updated]}"
  end

  desc "Fetch full text + embeddings for imported documents. " \
       "Usage: rails riksdagen:enrich_documents [TITLE_LIKE=skatt] [PARTY=S] [DOKTYP=mot] [LIMIT=50]"
  task enrich_documents: :environment do
    scope = Document.where(full_text: nil)
    scope = scope.where("titel ILIKE ?", "%#{ENV["TITLE_LIKE"]}%") if ENV["TITLE_LIKE"].present?
    scope = scope.where(party_code: ENV["PARTY"]) if ENV["PARTY"].present?
    scope = scope.where(doktyp: ENV["DOKTYP"]) if ENV["DOKTYP"].present?
    scope = scope.limit(ENV.fetch("LIMIT", 50).to_i)

    documents = scope.to_a
    puts "Fetching full text for #{documents.size} documents..."

    fetched = documents.select do |document|
      Riksdagen::FullTextFetcher.call(document)
    rescue Riksdagen::FullTextFetcher::Error => e
      warn "  skip #{document.dok_id}: #{e.message}"
      false
    end
    puts "Fetched #{fetched.size}/#{documents.size}."

    to_embed = fetched.select { |d| d.full_text.present? }
    puts "Embedding #{to_embed.size} documents..."
    embedded = Embeddings::DocumentEmbedder.call(to_embed)
    puts "Done. Embedded #{embedded}."
  end
end
