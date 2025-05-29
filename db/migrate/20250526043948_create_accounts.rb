class CreateAccounts < ActiveRecord::Migration[7.1]
  def change
    create_table :accounts do |t|
      t.string :name
      t.integer :due_day
      t.integer :closing_day

      t.references :account_type, null: false, foreign_key: true

      t.timestamps
    end
  end
end
