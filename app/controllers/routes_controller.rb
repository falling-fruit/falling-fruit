class RoutesController < ApplicationController
  before_filter :authenticate_user!
  authorize_resource

  def show
    @route = Route.find(params[:id])
    @route_locations = LocationsRoute.where("route_id = ?",@route.id).order(:position)
    @start_location = @route_locations[0].location
    @stop_location = @route_locations[@route_locations.length-1].location
    respond_to do |format|
      format.html
      format.mobile
    end
  end

  # DELETE /types/1
  # DELETE /types/1.json
  def destroy
    @route = Route.find(params[:id])
    @route.destroy

    respond_to do |format|
      format.html { redirect_to routes_url }
      format.json { head :no_content }
    end
  end

  def index
    @routes = Route.where("user_id = ?",current_user.id)
  end

  def edit
    @route = Route.find(params[:id])
  end

  def update
    @route = Route.find(params[:id])

    respond_to do |format|
      if @route.update_attributes(params[:route])
        format.html { redirect_to routes_path, notice: 'Route was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @route.errors, status: :unprocessable_entity }
      end
    end
  end

end
