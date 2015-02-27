class AddSpamToChanges < ActiveRecord::Migration
  def change
    add_column :changes, :spam, :boolean, :default => false
  end
end
