require 'role_model'

class User < ActiveRecord::Base
  has_many :locations
  has_many :observations
  has_many :changes

  ROLES = %w[admin forager partner guest]

  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable,
  # :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,
         :confirmable

  include RoleModel

  # Setup accessible (or protected) attributes for your model
  attr_accessible :email, :email_confirmation, :password, :password_confirmation, :remember_me, :range,
                  :name, :bio, :roles, :roles_mask, :remember_me, :add_anonymously,
                  :range_updates_email, :announcements_email

  validates :email, confirmation: true
  
  roles_attribute :roles_mask
  roles :admin, :forager, :partner, :guest

  # https://github.com/ryanb/cancan/wiki/Role-Based-Authorization
  def roles=(roles)
    self.roles_mask = (roles & ROLES).map { |r| 2**ROLES.index(r) }.inject(0, :+)
  end

  def roles
    ROLES.reject do |r|
      ((roles_mask || 0) & 2**ROLES.index(r)).zero?
    end
  end

  def is?(role)
    roles.include?(role.to_s)
  end

  # make current_user available in Model context
  class << self
    def current_user=(user)
      Thread.current[:current_user] = user
    end

    def current_user
      Thread.current[:current_user]
    end
  end

end
