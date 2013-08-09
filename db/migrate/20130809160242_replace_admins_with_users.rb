class Admin < ActiveRecord::Base
  attr_accessible :email, :password, :password_confirmation,
                  :name, :bio, :roles, :roles_mask, :remember_me
end

class ReplaceAdminsWithUsers < ActiveRecord::Migration
  def up
    change_table :changes do |t|
      t.references :user
    end

    Admin.all.each do |a|
      $stderr.puts a.email
      u = User.new
      u.email = a.email
      u.encrypted_password = a.encrypted_password
      u.confirmed_at = Time.now
      u.roles = ["admin","forager"]
      u.save(:validate => false)
      Change.where("admin_id = ?",a.id).each do |c|
        c.user_id = u.id
        c.save
      end
    end

    remove_column :changes, :admin_id
    drop_table :admins
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
