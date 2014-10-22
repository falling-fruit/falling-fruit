class SessionsController < Devise::SessionsController
  def create
    resource = warden.authenticate!(auth_options)
    sign_in(resource_name, resource)
    respond_to do |format|
      format.json { render json: { auth_token: current_user.authentication_token } }
      format.html { redirect_to after_sign_in_path_for(resource) }
    end


  end

  def destroy
    current_user.authentication_token = nil
    super
  end
end