class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new # guest user (not logged in)
    if user.is? :admin
      can :manage, :all
    elsif user.is? :partner
      # let them edit themself and their organization info
      can :update, User, :id => user.id
    elsif user.is? :forager or user.is? :guest
      # let them edit themselves and their routes...
      can :update, User, :id => user.id
      can [:read, :create, :update, :reposition], Route, :user_id => user.id
    end

    # Things everyone can do
    can [:read, :create, :update, :enroute], [Location]
    can :read, [Type, Change] 
    can [:read, :bibliography], Import
    can :read, Route, :is_public => true
  end
end
