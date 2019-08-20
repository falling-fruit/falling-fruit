class PresenceConstraintImportsName < ActiveRecord::Migration
  def up
    change_column :imports, :name, :string, null: false
  end

  def down
    change_column :imports, :name, :string, null: true 
  end
end
