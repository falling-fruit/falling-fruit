class AddSlovakNameToTypes < ActiveRecord::Migration
  def change
    add_column :types, :sk_name, :string, :default => nil
  end
end
