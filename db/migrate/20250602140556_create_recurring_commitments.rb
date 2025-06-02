class CreateRecurringCommitments < ActiveRecord::Migration[7.1]
  def change
    create_table :recurring_commitments do |t|
      t.string :name, null: false
      t.references :category, null: false, foreign_key: true
      t.decimal :default_amount, precision: 15, scale: 2
      t.string :recurrence_frequency, null: false, default: 'monthly'
      t.date :start_date, null: false
      t.date :end_date
      t.integer :status, null: false, default: 0
      t.text :notes

      t.timestamps
    end
    
    add_index :recurring_commitments, :status
    add_index :recurring_commitments, :recurrence_frequency
  end
end
