class AddStatusToChatMessages < ActiveRecord::Migration[8.1]
  def up
    add_column :chat_messages, :status, :string, null: false, default: "complete"
    change_column_null :chat_messages, :content, true
  end

  def down
    ChatMessage.where(content: nil).delete_all
    change_column_null :chat_messages, :content, false
    remove_column :chat_messages, :status
  end
end
