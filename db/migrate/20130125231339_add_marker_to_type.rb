class AddMarkerToType < ActiveRecord::Migration
  def self.up
    add_attachment :types, :marker
  end
  def self.down
    remove_attachment :types, :marker
  end
end
