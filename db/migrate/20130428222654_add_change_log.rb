class AddChangeLog < ActiveRecord::Migration
  def up
    create_table :changes do |t|
      t.references :location
      t.references :admin
      t.string :remote_ip
      t.text :description
      t.timestamps
    end
  end

  def down
    drop_table :changes
  end
end
