class AddStuffToRoutes < ActiveRecord::Migration
  def up
    rename_column :routes, :type, :transport_type

    change_table "routes" do |t|
      t.boolean :is_public, :null => false, :default => true
      t.string :access_key
    end

    Route.all.each do |r|
      r.is_public = true
      r.access_key = Digest::MD5.hexdigest(rand.to_s)
      r.save
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
