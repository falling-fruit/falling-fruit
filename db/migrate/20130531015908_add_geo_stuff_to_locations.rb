class AddGeoStuffToLocations < ActiveRecord::Migration
  def change
    change_table :locations do |t|
      t.string :city
      t.string :state
      #t.string :state_code
      t.string :country
      #t.string :country_code
    end
  end
end
