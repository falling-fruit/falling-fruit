class RemoveLocationCategoryMask < ActiveRecord::Migration
  def up
    remove_column :locations, :category_mask
  end

  def down
    add_column :locations, :category_mask, :integer
  end
end
