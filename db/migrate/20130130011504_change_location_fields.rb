class ChangeLocationFields < ActiveRecord::Migration
  def up
    remove_column :locations, :title
    remove_column :locations, :rating
    remove_column :locations, :inaccessible
    change_table :locations do |t|
      t.integer :quality_rating
      t.integer :yield_rating
      t.integer :access
    end
    create_table :observations do |t|
      t.references :location
      t.boolean :is_fruiting
      t.text :comment
      t.date :observed_on
    end
    add_attachment :observations, :photo
  end

  def down
    change_table :locations do |t|
      t.integer :rating
      t.integer :title
      t.boolean :inaccessible
    end
    remove_column :locations, :yield_rating
    remove_column :locations, :quality_rating
    remove_column :locations, :access
    drop_table :observations
  end
end
