class AddOriginalIdToLocations < ActiveRecord::Migration
  def change
    add_column :locations, :original_id, :integer, :default => nil
  end
end
