class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new # guest user (not logged in)
    if user.has_role? :admin
      can :manage, :all
    elsif user.has_role? :forager
      # let them edit themselves...
    elsif user.has_role? :partner
      # let them edit themself and their organization info
    end

    # Things everyone can do
    can [:read, :create, :update], [Location, LocationsType]
    can :read, [Type, Change]
  end
end
