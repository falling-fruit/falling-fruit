class AddArabicNameToTypes < ActiveRecord::Migration
  def change
    add_column :types, :ar_name, :string, :default => nil
  end
end
