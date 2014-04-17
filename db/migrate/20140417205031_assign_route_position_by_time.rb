class AssignRoutePositionByTime < ActiveRecord::Migration
  def change
    Route.all.each{ |route|
      i = 0
      LocationsRoute.where("route_id = ?",route.id).order("created_at ASC").each{ |lr|
        lr.position = i
        lr.save
        i += 1
      }
    }
  end
end
