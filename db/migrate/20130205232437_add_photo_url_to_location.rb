class AddPhotoUrlToLocation < ActiveRecord::Migration
  def change
    change_table :locations do |t|
      t.string :photo_url
    end
  end
end
