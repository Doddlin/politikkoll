module Manifestos
  # Downloads a party's valmanifest — a PDF or a plain web page — and turns
  # it into embedded, searchable chunks. Re-running for the same party/
  # election_year replaces the existing chunks rather than accumulating
  # duplicates.
  #
  # PDFs are OCRed via Mistral (handles multi-column layouts correctly,
  # unlike naive PDF text extraction — naive extraction was tried first and
  # produced interleaved, garbled text on these designs). Plain web pages
  # (e.g. a party's "vallöften" campaign page, increasingly common alongside
  # or instead of a PDF) are parsed directly and rendered into the same
  # lightweight heading-delimited markdown shape the OCR path produces, so
  # both sources share one chunking/embedding pipeline downstream.
  class Importer
    class Error < StandardError; end

    MAX_CHUNK_CHARS = 2000
    HTML_CONTENT_TYPE = "text/html"

    # Chrome/navigation/boilerplate elements to drop entirely before reading
    # the page's text — none of it is manifesto content.
    SKIP_SELECTORS = %w[script style nav header footer aside svg iframe noscript form].freeze
    CONTENT_SELECTORS = %w[h1 h2 h3 h4 h5 h6 p li blockquote].freeze

    def self.call(...)
      new(...).call
    end

    def initialize(url:, party_code:, election_year:, client: Mistral::Client.new)
      @url = url
      @party = Party.find_by!(code: party_code)
      @election_year = election_year
      @client = client
    end

    def call
      markdown = extract_markdown
      bodies = chunk_sections(markdown)
      raise Error, "No extractable text found at #{@url}" if bodies.empty?

      ManifestoChunk.where(party: @party, election_year: @election_year).destroy_all

      chunks = bodies.map do |body|
        ManifestoChunk.create!(
          party: @party, election_year: @election_year,
          section_title: body[:title], content: body[:content], source_url: @url
        )
      end

      Embeddings::ManifestoChunkEmbedder.call(chunks)
      { chunks: chunks.size }
    end

    private

    def extract_markdown
      response = fetch(@url)

      if response.headers["content-type"].to_s.include?(HTML_CONTENT_TYPE)
        extract_html_markdown(response.body)
      else
        extract_pdf_markdown
      end
    end

    def fetch(url)
      connection = Faraday.new do |f|
        # Same connection-failure coverage as the other external clients in
        # this app (Faraday's own retry default only covers timeouts).
        f.request :retry, max: 3, interval: 1, backoff_factor: 2,
                          exceptions: [
                            Faraday::ConnectionFailed, Faraday::TimeoutError,
                            Errno::ECONNRESET, Errno::ETIMEDOUT
                          ]
        f.adapter Faraday.default_adapter
      end
      connection.get(url)
    rescue Faraday::Error => e
      raise Error, "Could not fetch #{url}: #{e.message}"
    end

    # Walks the page's main content in document order and renders headings/
    # paragraphs/list items as the same "#"-heading, blank-line-separated
    # markdown shape chunk_sections/split_to_size already expect.
    def extract_html_markdown(html)
      # Explicit encoding matters here: some real-world pages have byte
      # sequences that make libxml2's encoding sniffer give up entirely
      # (fatal error, empty tree, no <body>) unless told what to expect —
      # confirmed live against a real party campaign page.
      doc = Nokogiri::HTML(html, nil, "UTF-8")
      doc.css(SKIP_SELECTORS.join(", ")).remove

      root = doc.at_css("main, article") || doc.at_css("body")
      return "" if root.nil?

      root.css(CONTENT_SELECTORS.join(", ")).filter_map do |node|
        text = node.text.squish
        next if text.blank?

        case node.name
        when /\Ah([1-6])\z/ then "#{"#" * $1.to_i} #{text}"
        when "li" then "- #{text}"
        else text
        end
      end.join("\n\n")
    end

    def extract_pdf_markdown
      response = @client.ocr(document_url: @url)
      response["pages"].map { |page| inline_figure_descriptions(page) }.join("\n\n")
    rescue Mistral::Client::Error => e
      raise Error, "OCR failed for #{@url}: #{e.message}"
    end

    # Charts/figures come through as a bare "![id](id)" reference in the
    # markdown — swap each one for the vision-model description of what it
    # actually shows, so chart data ends up searchable and embeddable
    # instead of silently disappearing.
    def inline_figure_descriptions(page)
      page["images"].reduce(page["markdown"]) do |markdown, image|
        description = JSON.parse(image["image_annotation"] || "{}")["description"]
        next markdown if description.blank?

        markdown.gsub("![#{image["id"]}](#{image["id"]})", "\n[Bild: #{description}]\n")
      end
    end

    # Splits on the document's own markdown headings so each chunk keeps a
    # meaningful section_title, then sub-splits any section that's still too
    # long for one embedding into paragraph-bounded pieces.
    def chunk_sections(markdown)
      sections = split_by_heading(markdown)

      sections.flat_map do |section|
        bodies = split_to_size(section[:content])
        multi = bodies.size > 1

        bodies.each_with_index.map do |content, i|
          title = multi ? "#{section[:title]} (#{i + 1}/#{bodies.size})" : section[:title]
          { title: title, content: content }
        end
      end
    end

    def split_by_heading(markdown)
      sections = []
      title = nil
      body_lines = []

      flush = -> { sections << { title: title, content: body_lines.join("\n").strip } if body_lines.join.strip.present? }

      markdown.each_line do |line|
        if line.chomp =~ /\A(#+)\s+(.*)\z/
          flush.call
          title = $2.strip
          body_lines = []
        else
          body_lines << line
        end
      end
      flush.call

      sections
    end

    def split_to_size(text)
      paragraphs = text.split(/\n\s*\n/).map(&:strip).reject(&:blank?)
      chunks = []
      current = +""

      paragraphs.each do |paragraph|
        if current.present? && current.length + paragraph.length + 2 > MAX_CHUNK_CHARS
          chunks << current.strip
          current = +""
        end
        current << paragraph << "\n\n"
      end
      chunks << current.strip if current.present?

      chunks.presence || [ text.strip ]
    end
  end
end
