class AddItalianNameToTypes < ActiveRecord::Migration
  def change
    add_column :types, :it_name, :string, :default => nil
  end
end
