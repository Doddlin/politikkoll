class ChatsController < ApplicationController
  before_action :set_conversation

  def new
  end

  # A question submitted from the dedicated chat page updates in place via
  # Turbo Stream (no navigation). One submitted inline from a document page
  # still redirects into the full chat thread — that page has no #thread
  # element to stream into, and jumping into the main conversation is the
  # actual intent there.
  def create
    user_message = @conversation.chat_messages.create!(role: "user", content: build_question)
    assistant_message = @conversation.chat_messages.create!(role: "assistant", status: "pending")

    Chat::AnswerJob.perform_later(assistant_message.id, I18n.locale.to_s)

    if params[:document_id].present?
      redirect_to new_chat_path
    else
      @messages = [ user_message, assistant_message ]
      render formats: :turbo_stream
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
