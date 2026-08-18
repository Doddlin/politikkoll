module Riksdagen
  # Fetches a document's full text from data.riksdagen.se. The ".text" URL
  # despite its name returns an XML wrapper with the actual content as
  # escaped HTML in a <html> field (fonts, CSS and all) — this strips that
  # down to plain, readable text.
  class FullTextFetcher
    class Error < StandardError; end

    USER_AGENT = "Politikkoll/1.0 (didrik@bvconsulting.se)".freeze

    def self.call(...)
      new(...).call
    end

    def self.clean_text(text)
      text.gsub(" ", " ") # non-breaking space survives String#strip otherwise
        .lines.map(&:strip).join("\n")
        .gsub(/\n{2,}/, "\n\n")
        .strip
    end

    def initialize(document)
      @document = document
      @connection = Faraday.new do |f|
        # Sätt en tydlig User-Agent och Accept-header
        f.headers["User-Agent"] = USER_AGENT
        f.headers["Accept"] = "text/xml, application/xml"

        # Sätt explicit hantering av nätverksfel och kopplingsavbrott
        f.request :retry,
                  max: 3,
                  interval: 1,
                  backoff_factor: 2,
                  exceptions: [
                    Faraday::ConnectionFailed,
                    Faraday::TimeoutError,
                    Errno::ECONNRESET,
                    Errno::ETIMEDOUT
                  ]

        # Sätt rimliga timeouts så att sökningen inte hänger sig
        f.options.open_timeout = 5
        f.options.timeout = 10

        f.adapter Faraday.default_adapter
      end
    end

    def call
      url = "https://data.riksdagen.se/dokument/#{ERB::Util.url_encode(@document.dok_id)}.text"
      response = @connection.get(url)
      raise Error, "HTTP #{response.status} fetching #{@document.dok_id}" unless response.success?

      text = extract_text(response.body.force_encoding(Encoding::UTF_8))
      return false if text.blank?

      @document.update!(full_text: text)
      true
    rescue Faraday::Error, Errno::ECONNRESET => e
      raise Error, "Network error fetching #{@document.dok_id}: #{e.message}"
    end

    private

    def extract_text(raw_xml)
      outer = Nokogiri::XML(raw_xml)
      inner_html = outer.at_xpath("//html")&.text
      return nil if inner_html.blank?

      fragment = Nokogiri::HTML5.fragment(inner_html)
      fragment.css("style, script").each(&:remove)

      self.class.clean_text(fragment.text)
    end
  end
end