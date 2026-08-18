class AddVoteBoardsToChatMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :chat_messages, :vote_boards, :jsonb, null: false, default: []
  end
end
