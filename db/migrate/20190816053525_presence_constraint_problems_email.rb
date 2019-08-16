class PresenceConstraintProblemsEmail < ActiveRecord::Migration
  def up
    change_column :problems, :email, :string, null: false
  end

  def down
    change_column :problems, :email, :string, null: true
  end
end
