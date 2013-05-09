class AddClientTypeToLocation < ActiveRecord::Migration
  def change
    change_table :locations do |t|
      t.string :client, :default => 'web'
    end
    execute "UPDATE locations SET client='import' WHERE import_id IS NOT NULL"
  end
end
