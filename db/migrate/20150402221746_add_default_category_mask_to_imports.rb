class AddDefaultCategoryMaskToImports < ActiveRecord::Migration
  def change
    add_column :imports, :default_category_mask, :integer, :default => 0
  end
end
