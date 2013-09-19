class ChangesController < ApplicationController

  # GET /types
  # GET /types.json
  def index
    r = ActiveRecord::Base.connection.execute("SELECT string_agg(coalesce(t.name,lt.type_other),',') as type_title,
      extract(days from (NOW()-c.created_at)) as days_ago, c.location_id, c.user_id, c.description, c.remote_ip, l.city, l.state, l.country,
      array_agg(lt.position) as positions
      FROM changes c, locations l, locations_types lt left outer join types t on lt.type_id=t.id
      WHERE lt.location_id=l.id AND l.id=c.location_id
      GROUP BY l.id, c.location_id, c.user_id, c.description, c.remote_ip, c.created_at ORDER BY c.created_at DESC LIMIT 100");
    @changes = r.collect{ |row| row }
    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @changes }
    end
  end

end
