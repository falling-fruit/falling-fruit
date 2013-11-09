class AddUrLsToTypes < ActiveRecord::Migration
  def change
    change_table :types do |t|
      t.string "urban_mushrooms_url"
      t.string "fruitipedia_url"
      t.string "eat_the_weeds_url"
      t.string "foraging_texas_url"
    end
  end
end
