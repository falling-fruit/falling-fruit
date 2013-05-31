class AddGeoStuffToLocations < ActiveRecord::Migration
  def change
    change_table :locations do |t|
      t.string :city
      t.string :state
      t.string :country
    end
  end
end
