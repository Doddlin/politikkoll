namespace :manifestos do
  desc "Import a party's valmanifest PDF. Usage: rails manifestos:import URL=... PARTY=M YEAR=2022"
  task import: :environment do
    url = ENV.fetch("URL") { abort "Usage: rails manifestos:import URL=... PARTY=M YEAR=2022" }
    party = ENV.fetch("PARTY") { abort "Usage: rails manifestos:import URL=... PARTY=M YEAR=2022" }
    year = ENV.fetch("YEAR") { abort "Usage: rails manifestos:import URL=... PARTY=M YEAR=2022" }

    puts "Importing #{party} #{year} manifesto from #{url}..."
    stats = Manifestos::Importer.call(url: url, party_code: party, election_year: year.to_i)
    puts "Done. #{stats[:chunks]} chunks embedded."
  end
end
