class AddOtherAttrsToUser < ActiveRecord::Migration
  def change
    change_table :users do |t|
      t.boolean :range_updates_email, :default => false, :null => false
      t.boolean :add_anonymously, :default => false, :null => false
    end
  end
end
