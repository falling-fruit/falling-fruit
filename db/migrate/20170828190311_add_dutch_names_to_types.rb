class AddDutchNamesToTypes < ActiveRecord::Migration
  def change
    add_column :types, :nl_name, :string, :default => nil
  end
end
