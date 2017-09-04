class RenameTypeEdability < ActiveRecord::Migration
  def up
    rename_column :types, :edability, :edibility
  end

  def down
    rename_column :table, :edibility, :edability
  end
end
