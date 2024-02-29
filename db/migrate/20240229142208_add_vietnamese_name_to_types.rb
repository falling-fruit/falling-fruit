class AddVietnameseNameToTypes < ActiveRecord::Migration
  def change
    add_column :types, :vi_name, :string, :default => nil
  end
end
