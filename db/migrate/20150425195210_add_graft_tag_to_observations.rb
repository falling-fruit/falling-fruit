class AddGraftTagToObservations < ActiveRecord::Migration
  def change
    add_column :observations, :graft, :boolean, :default => false
  end
end
