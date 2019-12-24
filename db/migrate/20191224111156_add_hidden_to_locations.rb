class AddHiddenToLocations < ActiveRecord::Migration
  def change
    add_column :locations, :hidden, :boolean, :default => false
    add_index(:locations, :hidden)
  end
end
