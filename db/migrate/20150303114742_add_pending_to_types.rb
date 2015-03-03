class AddPendingToTypes < ActiveRecord::Migration
  def change
    add_column :types, :pending, :boolean, :default => false
  end
end
