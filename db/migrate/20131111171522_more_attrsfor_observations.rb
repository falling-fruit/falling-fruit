class MoreAttrsforObservations < ActiveRecord::Migration
  def change
    remove_column :observations, :is_fruiting
    change_table :observations do |t|
      t.integer :fruiting
      t.integer :quality_rating
      t.integer :yield_rating
      t.references :user
      t.string :remote_ip
      t.string :author
      t.timestamps
    end
    change_table :locations do |t|
      t.references :user
    end
  end
end
