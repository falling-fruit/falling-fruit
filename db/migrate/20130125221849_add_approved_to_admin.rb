class AddApprovedToAdmin < ActiveRecord::Migration
  def change
    add_column :admins, :approved, :boolean
  end
end
