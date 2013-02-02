class FixImportsId < ActiveRecord::Migration
  def up
    remove_column :locations, :imports_id
    change_table :locations do |t|
      t.references :import
    end
  end

  def down
    remove_column :locations, :import_id
    change_table :locations do |t|
      t.references :imports
    end
  end
end
