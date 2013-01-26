class Admin < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable,
  # :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  # Setup accessible (or protected) attributes for your model
  attr_accessible :email, :password, :password_confirmation, :remember_me, :approved
  # attr_accessible :title, :body

  def active_for_authentication? 
    super && approved? 
  end 
  def inactive_message 
    if !approved? 
      :not_approved 
    else 
       super # Use whatever other message 
    end 
  end
end
