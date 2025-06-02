class CreateInstallmentPlans < ActiveRecord::Migration[7.1]
  def change
    create_table :installment_plans do |t|
      t.string :name, null: false
      t.integer :installment_count, null: false
      t.string :recurrence_frequency, null: false, default: 'monthly'
      t.date :starts_on, null: false
      t.integer :status, null: false, default: 0
      t.text :notes
      t.decimal :total_amount, precision: 15, scale: 2

      t.timestamps
    end
    
    add_index :installment_plans, :status
    add_index :installment_plans, :recurrence_frequency
  end
end
