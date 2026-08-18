class AddVotesCheckedAtToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :votes_checked_at, :datetime
  end
end
