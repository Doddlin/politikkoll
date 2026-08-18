module Scb
  # A small, hand-verified set of SCB tables relevant to political claims —
  # deliberately curated rather than letting the model browse SCB's full
  # table catalog live, since PxWeb's variable/value codes (like "ALÖS" for
  # "unemployed") aren't something a model can reliably guess. Each entry
  # here was tested against the real API before being added; add more the
  # same way (browse api.scb.se, confirm the table and codes actually
  # return what you expect, then register it).
  module Topics
    REGISTRY = {
      "arbetslöshet" => {
        label_sv: "Arbetslöshet, 15–74 år (AKU)",
        table_path: "/AM/AM0401/AM0401L/NAKUArblheltidstudAr",
        unit: "procent",
        query: {
          query: [
            { code: "Arbetskraftstillh", selection: { filter: "item", values: [ "ALÖS" ] } },
            { code: "Kon", selection: { filter: "item", values: [ "1+2" ] } },
            { code: "Alder", selection: { filter: "item", values: [ "tot15-74" ] } },
            { code: "ContentsCode", selection: { filter: "item", values: [ "AM04011Q" ] } }
          ],
          response: { format: "json" }
        }
      },
      "inflation" => {
        label_sv: "Inflation (KPI, årsförändring i procent, beräknat från indextal)",
        table_path: "/PR/PR0101/PR0101L/KPIFastAmed",
        unit: "procent (årsförändring)",
        derive: :year_over_year_percent,
        query: {
          query: [
            { code: "ContentsCode", selection: { filter: "item", values: [ "000000KL" ] } }
          ],
          response: { format: "json" }
        }
      },
      "invandring" => {
        label_sv: "Invandring till Sverige, totalt",
        table_path: "/BE/BE0101/BE0101J/ImmiEmiFod",
        unit: "personer",
        query: {
          query: [
            { code: "Fodelseland", selection: { filter: "item", values: [ "TOT" ] } },
            { code: "Kon", selection: { filter: "item", values: [ "1", "2" ] } },
            { code: "ContentsCode", selection: { filter: "item", values: [ "BE0101M3" ] } }
          ],
          response: { format: "json" }
        }
      },
      "bostadsbyggande" => {
        label_sv: "Färdigställda lägenheter i nybyggda hus, hela Sverige",
        table_path: "/BO/BO0101/BO0101A/LghReHustypAr",
        unit: "lägenheter",
        query: {
          query: [
            { code: "Region", selection: { filter: "item", values: [ "00" ] } },
            { code: "Hustyp", selection: { filter: "item", values: [ "FLERBO", "SMÅHUS" ] } },
            { code: "ContentsCode", selection: { filter: "item", values: [ "BO0101A5" ] } }
          ],
          response: { format: "json" }
        }
      }
    }.freeze

    def self.available
      REGISTRY.keys
    end

    def self.fetch(key)
      REGISTRY.fetch(key)
    end
  end
end
