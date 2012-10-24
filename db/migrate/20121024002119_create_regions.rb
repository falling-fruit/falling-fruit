class CreateRegions < ActiveRecord::Migration
  def change
    create_table :regions do |t|
      t.string :name
      t.text :center_address
      t.float :center_lat
      t.float :center_lng

      t.timestamps
    end
  end
end
