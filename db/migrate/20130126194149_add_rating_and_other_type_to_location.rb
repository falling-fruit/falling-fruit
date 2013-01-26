class AddRatingAndOtherTypeToLocation < ActiveRecord::Migration
  def change
    change_table :locations do |t|
      t.string :type_other
      t.integer :rating
    end
  end
end
