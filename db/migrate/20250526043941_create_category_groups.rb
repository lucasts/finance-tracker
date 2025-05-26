class CreateCategoryGroups < ActiveRecord::Migration[7.1]
  def change
    create_table :category_groups do |t|
      t.string :code
      t.string :name

      t.timestamps
    end
    add_index :category_groups, :code, unique: true
  end
end
