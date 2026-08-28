module Chat
  # Runs Chat::Answerer's Mistral round-trip (potentially several tool-call
  # rounds, each a real HTTP call) outside the request/response cycle — the
  # form submit that creates the pending ChatMessage returns immediately,
  # and this fills it in and broadcasts the result whenever it's actually
  # ready. Keeps a slow or failing AI call from tying up a Puma worker (or
  # exceeding a proxy timeout in front of the app) for the whole answer.
  class AnswerJob < ApplicationJob
    queue_as :default

    # locale: the asker's session locale — a job has no session of its own
    # to read it from, so it's passed through explicitly and applied for
    # the duration of the run. Matters for both the user-facing failure
    # text (fail! below) and the broadcasted partial's own t() calls
    # (labels, vote board text) once the answer's ready.
    def perform(chat_message_id, locale = I18n.default_locale.to_s)
      I18n.with_locale(locale) do
        assistant_message = ChatMessage.find(chat_message_id)
        Chat::Answerer.new.ask(assistant_message)
      end
    end
  end
end
