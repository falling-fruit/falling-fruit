class UsersController < ApplicationController
  before_filter :authenticate_user!
  authorize_resource

  def index
    @users = User.all
    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @users }
    end
  end

  # switch to a particular user
  def switch
    user = User.find(params[:id].to_i)
    sign_out(current_user)
    sign_in(user)
    flash[:notice] = "Successfully switched to user #{current_user.name}."
    redirect_to after_sign_in_path_for(current_user)
  end

  def destroy
    @user = User.find(params[:id])
    @user.destroy
    respond_to do |format|
      format.html { redirect_to users_url }
      format.json { head :no_content }
    end
  end


end
