class CreateAccountTypes < ActiveRecord::Migration[7.1]
  def change
    create_table :account_types do |t|
      t.string :code
      t.string :role
      t.string :name

      t.timestamps
    end
    add_index :account_types, :code, unique: true
  end
end
