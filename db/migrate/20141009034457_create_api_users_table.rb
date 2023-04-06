class CreateApiUsersTable < ActiveRecord::Migration
  def up
    create_table :api_keys do |t|
      t.string :api_key
      t.integer :version, :default => 0, :null => false
      t.string :api_type
      t.string :name
      t.timestamps
    end
  end

  def down
    drop_table :api_keys
  end
end
