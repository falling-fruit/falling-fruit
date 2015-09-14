class CreateInvasivesTable < ActiveRecord::Migration
  def up
    create_table :invasives do |t|
      t.multi_polygon :regions, :geographic => true
      t.references :type
      t.string :source
    end
    change_table :invasives do |t|
      t.index :regions, :spatial => true
      t.index :type_id
    end
  end

  def down
    drop_table :invasives
  end
end
