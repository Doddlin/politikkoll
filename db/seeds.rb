# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

PARTIES = {
  "S"  => { name: "Socialdemokraterna",   color: "#E53950" },
  "M"  => { name: "Moderaterna",          color: "#3B82F6" },
  "SD" => { name: "Sverigedemokraterna",  color: "#EAC435" },
  "C"  => { name: "Centerpartiet",        color: "#4C8C4A" },
  "V"  => { name: "Vänsterpartiet",       color: "#922B3E" },
  "KD" => { name: "Kristdemokraterna",    color: "#1B3E7A" },
  "L"  => { name: "Liberalerna",          color: "#06B6D4" },
  "MP" => { name: "Miljöpartiet",         color: "#65C34D" },
  "-"  => { name: "Partilös",             color: "#9AA0B4" }
}.freeze

PARTIES.each do |code, attrs|
  party = Party.find_or_initialize_by(code: code)
  party.name = attrs[:name]
  party.color = attrs[:color]
  party.save!
end

puts "Seeded #{Party.count} parties."
