class AddCaptionToPhotos < ActiveRecord::Migration
  def change
    change_table :observations do |t|
      t.text :photo_caption
    end
  end
end
