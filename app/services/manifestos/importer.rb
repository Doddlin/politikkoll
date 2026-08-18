module Manifestos
  # Downloads a party's valmanifest PDF, OCRs it via Mistral (handles
  # multi-column layouts correctly, unlike naive PDF text extraction —
  # naive extraction was tried first and produced interleaved, garbled
  # text on these designs), chunks it by the document's own markdown
  # headings, and embeds each chunk. Re-running for the same party/
  # election_year replaces the existing chunks rather than accumulating
  # duplicates.
  class Importer
    class Error < StandardError; end

    MAX_CHUNK_CHARS = 2000

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
