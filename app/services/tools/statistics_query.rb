module Tools
  # Looks up real SCB (Statistics Sweden) time series for a curated set of
  # topics — the tool for checking whether a political claim or trend
  # matches what actually happened, independent of what any party says.
  # Results are cached for a day; SCB is rate-limited and yearly government
  # statistics don't need a live call on every chat message.
  class StatisticsQuery
    SCHEMA = {
      type: "function",
      function: {
        name: "query_statistics",
        description: "Look up real government statistics from Statistics Sweden (SCB) as a " \
                      "year-by-year series, for a supported topic. Use this to check a claim a " \
                      "party makes (in a motion, manifesto, or debate) against what the neutral " \
                      "official statistics actually show — this is independent government data, " \
                      "not something any party controls.",
        parameters: {
          type: "object",
          properties: {
            topic: {
              type: "string",
              enum: Scb::Topics.available,
              description: "One of the supported statistics topics."
            },
            from_year: { type: "integer", description: "Optional — only return years from this year onward." }
          },
          required: [ "topic" ]
        }
      }
    }.freeze

    def self.call(topic:, from_year: nil, client: Scb::Client.new)
      unless Scb::Topics.available.include?(topic)
        return { found: false, message: "Unknown topic '#{topic}'. Available: #{Scb::Topics.available.join(", ")}." }
      end

      config = Scb::Topics.fetch(topic)

      series = Rails.cache.fetch("scb/#{topic}", expires_in: 1.day) do
        response = client.query(config[:table_path], config[:query])
        parse_series(response)
      end

      series = apply_derivation(series, config[:derive]) if config[:derive]
      series = series.select { |row| row[:year] >= from_year } if from_year.present?

      { found: true, topic: topic, label: config[:label_sv], unit: config[:unit],
        source: "SCB (Statistiska centralbyrån)", series: series }
    end

    # Sums across any rows that share a year — some tables only split by a
    # demographic (sex, building type) rather than offering a pre-summed
    # "total", so a table with one row per year and one with several per
    # year (e.g. men + women) both come out correct here.
    def self.parse_series(response)
      dimension_columns = response["columns"].reject { |c| c["type"] == "c" }
      time_index = dimension_columns.index { |c| c["type"] == "t" }

      by_year = Hash.new(0.0)
      response["data"].each do |row|
        by_year[row["key"][time_index].to_i] += row["values"].first.to_f
      end

      by_year.map { |year, value| { year: year, value: value } }.sort_by { |row| row[:year] }
    end
    private_class_method :parse_series

    def self.apply_derivation(series, method)
      return series unless method == :year_over_year_percent

      series.each_cons(2).map do |prev, curr|
        { year: curr[:year], value: ((curr[:value] - prev[:value]) / prev[:value] * 100).round(1) }
      end
    end
    private_class_method :apply_derivation
  end
end
