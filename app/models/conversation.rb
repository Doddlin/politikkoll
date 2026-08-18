class Conversation < ApplicationRecord
  has_many :chat_messages, -> { order(:created_at) }, dependent: :destroy
end
