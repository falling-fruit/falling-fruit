class AddTurkishNamesToTypes < ActiveRecord::Migration
  def change
    add_column :types, :tr_name, :string, :default => nil
  end
end
