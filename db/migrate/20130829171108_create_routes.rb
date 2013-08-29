class CreateRoutes < ActiveRecord::Migration
  def change
    create_table :routes do |t|
      t.string :name
      t.references :user
      t.string :type

      t.timestamps
    end
    add_index :routes, :user_id
  end
end
