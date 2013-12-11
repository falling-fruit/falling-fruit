class RoutesController < ApplicationController
  before_filter :authenticate_user!, :except => :show
  authorize_resource

  def show
    @route = Route.find(params[:id])
    if @route.is_public or @route.user == current_user or (params[:k].present? and @route.access_key == params[:k])
      @route_locations = LocationsRoute.where("route_id = ?",@route.id).order(:position)
      @start_location = @route_locations[0].location
      @stop_location = @route_locations[@route_locations.length-1].location
      respond_to do |format|
        format.html
        format.mobile
      end
    else
      redirect_to root_path, notice: "You do not have permission to view that route."
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

  def multiupdate
    okay = params[:route].collect{ |id,data|
      route = Route.find(id)
      if data[:is_public].to_i == 1
        data[:is_public] = true
      else
        data[:is_public] = false
      end
      route.update_attributes(data) 
    }.all?

    respond_to do |format|
      if okay
        format.html { redirect_to routes_path, notice: 'Route was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "index" }
        format.json { render json: @route.errors, status: :unprocessable_entity }
      end
    end
  end

end
