class AddFileDigestToImportSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :import_sessions, :file_digest, :string
    add_index :import_sessions, [:account_id, :file_digest], unique: true
  end
end
