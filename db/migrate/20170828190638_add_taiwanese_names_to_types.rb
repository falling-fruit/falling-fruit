class AddTaiwaneseNamesToTypes < ActiveRecord::Migration
  def change
    add_column :types, :zh_tw_name, :string, :default => nil
  end
end
