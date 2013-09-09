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
      can [:create, :update], Route, :user_id => user.id
    end

    # Things everyone can do
    can [:read, :create, :update], [Location, LocationsType]
    can :read, [Type, Change, Import, Route]
  end
end
