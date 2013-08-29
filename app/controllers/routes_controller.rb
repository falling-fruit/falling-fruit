class RoutesController < ApplicationController

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

end
