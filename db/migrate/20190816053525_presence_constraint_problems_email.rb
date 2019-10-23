class PresenceConstraintProblemsEmail < ActiveRecord::Migration
  def up
    change_column_null :problems, :email, false, ''
  end

  def down
    change_column_null :problems, :email, true, ''
  end
end
