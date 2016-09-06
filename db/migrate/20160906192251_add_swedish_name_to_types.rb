class AddSwedishNameToTypes < ActiveRecord::Migration
  def change
    add_column :types, :sv_name, :string, :default => nil
  end
end
