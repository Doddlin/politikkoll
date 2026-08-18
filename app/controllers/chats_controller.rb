class ChatsController < ApplicationController
  before_action :set_conversation

  def new
    @error = nil
  end

  # A question submitted from the dedicated chat page updates in place via
  # Turbo Stream (no navigation). One submitted inline from a document page
  # still redirects into the full chat thread — that page has no #thread
  # element to stream into, and jumping into the main conversation is the
  # actual intent there.
  def create
    Chat::Answerer.new.ask(@conversation, build_question)

    if params[:document_id].present?
      redirect_to new_chat_path
    else
      @messages = @conversation.chat_messages.order(:created_at).last(2)
      render formats: :turbo_stream
    end
  rescue Mistral::Client::Error => e
    @error = e.message

    if params[:document_id].present?
      render :new, status: :bad_gateway
    else
      render formats: :turbo_stream, status: :bad_gateway
    end
  end

  def destroy
    session.delete(:conversation_id)
    redirect_to root_path
  end

  private

  def set_conversation
    @conversation = Conversation.find_by(id: session[:conversation_id])
    @conversation ||= Conversation.create!.tap { |c| session[:conversation_id] = c.id }
  end

  # A question submitted from a document page carries document_id so it
  # stays grounded on that document even if the user typed something vague
  # ("summarize it") or left the field blank entirely — params.require
  # treats a blank string as missing, so that path uses plain bracket
  # access instead, since a blank question is expected and valid here.
  def build_question
    document = Document.find_by(dok_id: params[:document_id]) if params[:document_id].present?
    return params.require(:question) unless document

    body = params[:question].presence || t("documents.chat_default_question")
    t("documents.chat_context", beteckning: document.beteckning, title: document.titel, question: body)
  end
end
