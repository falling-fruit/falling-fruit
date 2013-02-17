class MoreAttributesForImports < ActiveRecord::Migration
  def up
    change_table :imports do |t|
      t.datetime "created_at",                             :null => false, :default => 'NOW()'
      t.datetime "updated_at",                             :null => false, :default => 'NOW()'
      t.boolean "autoload",                                :default => true, :null => false
    end
  end

  def down
    remove_column :imports, :created_at
    remove_column :imports, :updated_at
    remove_column :imports, :autoload
  end
end
