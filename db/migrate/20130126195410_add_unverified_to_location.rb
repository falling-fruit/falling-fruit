class AddUnverifiedToLocation < ActiveRecord::Migration
  def change
    change_table :locations do |t|
      t.boolean :unverified, :default => false
    end
  end
end
