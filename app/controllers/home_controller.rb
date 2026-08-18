class HomeController < ApplicationController
  def index
    @ongoing_conversation = Conversation.find_by(id: session[:conversation_id])
    @ongoing_conversation = nil unless @ongoing_conversation&.chat_messages&.exists?

    @stats = {
      votes: Vote.count,
      betankanden: Document.where(doktyp: "bet").count,
      motioner: Document.where(doktyp: "mot").count,
      partier: Party.where.not(code: "-").count
    }

    @big_numbers = {
      documents: Document.count,
      searchable: Document.where.not(embedding: nil).count + ManifestoChunk.where.not(embedding: nil).count,
      members: Member.count,
      votes: Vote.count
    }

    @explorable_motions = Document.where(doktyp: "mot")
      .where.not(embedding: nil)
      .order(published_at: :desc)
      .limit(8)
      .to_a

    party_codes = @explorable_motions.map(&:party_code).compact.uniq
    @parties_by_code = Party.where(code: party_codes).index_by(&:code)
  end
end
