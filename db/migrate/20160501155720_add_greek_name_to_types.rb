class AddGreekNameToTypes < ActiveRecord::Migration
  def change
    add_column :types, :el_name, :string, :default => nil
  end
end
