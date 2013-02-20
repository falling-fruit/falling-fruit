class AddMuniFlagToImports < ActiveRecord::Migration
  def change
    change_table :imports do |t|
      t.boolean    :muni, :default => false
    end
  end
end
