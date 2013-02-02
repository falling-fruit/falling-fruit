class ApplicationController < ActionController::Base
  protect_from_forgery

  private

  before_filter :instantiate_controller_and_action_names
 
  def instantiate_controller_and_action_names
      @current_action = action_name
      @current_controller = controller_name
  end
end
