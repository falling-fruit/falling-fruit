class AddFormerInfoToChanges < ActiveRecord::Migration
  def up
    add_column :changes, :former_type_ids, :integer, :array => true, :default => []
    add_column :changes, :former_type_others, :string, :array => true, :default => []
    change_table :changes do |t|
      t.point :former_location, :geographic => true, :srid => 4326
    end
    change_table :changes do |t|
      t.index :former_location, :spatial => true
    end
  end
  def down
    remove_column :changes, :former_type_ids
    remove_column :changes, :former_type_others
    remove_column :changes, :former_location
  end
end
