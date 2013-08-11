class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new # guest user (not logged in)
    if user.is? :admin
      can :manage, :all
    elsif user.is? :partner
      # let them edit themself and their organization info
    elsif user.is? :forager or user.is? :guest
      # let them edit themselves...
    end

    # Things everyone can do
    can [:read, :create, :update], [Location, LocationsType]
    can :read, [Type, Change, Import]
  end
end
