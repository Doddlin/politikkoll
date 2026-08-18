module DocumentsHelper
  # Riksdagen documents follow a genuinely standardized template — these are
  # real, recurring section names verified against our own imported
  # documents (not a generic "short line = heading" guess, which misfires
  # on short sentence fragments the source text also happens to contain).
  SECTION_HEADINGS = [
    "Sammanfattning", "Innehållsförteckning",
    "Förslag till riksdagsbeslut", "Utskottets förslag till riksdagsbeslut",
    "Utskottets förslag i korthet", "Utskottets överväganden",
    "Utskottets ställningstagande", "Ställningstagande",
    "Reservationer", "Särskilda yttranden", "Bakgrund", "Motivering",
    "Ärendet och dess beredning", "Redogörelse för ärendet",
    "Tidigare riksdagsbehandling", "Pågående arbete", "Propositionen",
    "Motionen", "Motionerna"
  ].freeze

  NUMBERED_HEADING = /\A(Bilaga|Reservation|Särskilt yttrande)\s+\d+/

  def format_document_text(text)
    safe_join(text.to_s.split(/\n{2,}/).map { |paragraph| format_document_paragraph(paragraph) })
  end

  private

  def format_document_paragraph(paragraph)
    stripped = paragraph.strip
    return "".html_safe if stripped.blank?

    if SECTION_HEADINGS.include?(stripped) || stripped.match?(NUMBERED_HEADING)
      content_tag(:h2, stripped, class: "doc-section-heading")
    else
      lines = stripped.split("\n").map { |line| ERB::Util.html_escape(line) }
      content_tag(:p, safe_join(lines, tag.br))
    end
  end
end
