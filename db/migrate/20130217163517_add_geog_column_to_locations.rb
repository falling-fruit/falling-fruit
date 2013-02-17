class AddGeogColumnToLocations < ActiveRecord::Migration
  def change
    change_table :locations do |t|
      t.point :location, :geographic => true
    end
    change_table :locations do |t|
      t.index :location, :spatial => true
    end
  end
end
