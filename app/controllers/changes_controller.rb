class ChangesController < ApplicationController

  # GET /types
  # GET /types.json
  def index
    @changes = ActiveRecord::Base.connection.execute(
      "SELECT string_agg(COALESCE(
        t.#{Type.i18n_name_field}, t.#{Type.i18n_name_field('en')}, t.scientific_name
      ), ', ') as type_title,
      extract(days from (NOW()-c.created_at)) as days_ago,
      c.location_id, c.user_id, c.description, c.remote_ip,
      l.city, l.state, l.country
      FROM changes c, locations l, types t
      WHERE t.id=ANY(l.type_ids) AND l.id=c.location_id AND NOT c.spam
      GROUP BY l.id, c.location_id, c.user_id, c.description, c.remote_ip, c.created_at
      ORDER BY c.created_at DESC LIMIT 100").
      collect{ |row| row }
    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @changes }
    end
  end

end
