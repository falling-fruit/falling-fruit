class AddCategoryMask < ActiveRecord::Migration
  def up
    add_column :types, :category_mask, :integer, :default => 1
  end
  def down
    remove_column :types, :category_mask
  end
end
