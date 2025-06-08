class AddCategoryTypeToCategories < ActiveRecord::Migration[8.0]
  def change
    add_column :categories, :category_type, :integer, default: 1, null: false
    add_index :categories, :category_type
  end
end
