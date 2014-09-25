class Api::LocationsController < ApplicationController

  before_filter :authenticate_user!, :only => [:mine,:favorite]

  def mine
    @mine = Observation.joins(:location).select('max(observations.created_at) as created_at,observations.user_id,location_id,lat,lng').
      where("observations.user_id = ?",current_user.id).group("location_id,observations.user_id,lat,lng,observations.created_at").
      order('observations.created_at desc')
    @mine.uniq!{ |o| o.location_id }
    @mine.each_index{ |i|
      loc = @mine[i].location
      @mine[i] = loc.attributes
      @mine[i]["title"] = loc.title
      @mine[i].delete("user_id")
    }
    log_api_request("api/locations/mine",@mine.length)
    respond_to do |format|
      format.json { render json: @mine }
    end
  end

  def show
    @location = Location.find(params[:id])
    @location[:title] = @location.title
    @location[:photos] = @location.observations.collect{ |o|
      o.photo_file_name.nil? ? nil : { :updated_at => o.photo_updated_at, :url => o.photo.url }
    }.compact
    log_api_request("api/locations/show",1)
    respond_to do |format|
      format.json { render json: @location }
    end
  end

  def reviews
    @location = Location.find(params[:id])
    @obs = @location.observations
    @obs.each_index{ |i|
      @obs[i][:photo_url] = @obs[i].photo_file_name.nil? ? nil : @obs[i].photo.url
      @obs[i] = @obs[i].attributes
      @obs[i].delete("user_id")
      @obs[i].delete("remote_ip")
    }
    log_api_request("api/locations/reviews",@obs.length)
    respond_to do |format|
      format.json { render json: @location.observations }
    end
  end

  # Note: intersect on center_point so that count reflects counts shown on map
  def cluster_types
    cat_mask = array_to_mask(["human","freegan"],Type::Categories)
    mfilter = ""
    if params[:muni].present? and params[:muni].to_i == 1
      mfilter = ""
    elsif params[:muni].present? and params[:muni].to_i == 0
      mfilter = "AND NOT muni"
    end
    g = params[:grid].present? ? params[:grid].to_i : 2
    g = 12 if g > 12
    if [params[:nelat],params[:nelng],params[:swlat],params[:swlng]].any? { |e| e.nil? }
      bound = ""
    elsif params[:swlng].to_f < params[:nelng].to_f
      bound = "AND ST_INTERSECTS(cluster_point,ST_TRANSFORM(ST_SETSRID(ST_MakeBox2D(ST_POINT(#{params[:swlng]},#{params[:swlat]}), ST_POINT(#{params[:nelng]},#{params[:nelat]})),4326),900913))"
    else # map spans -180 | 180 seam, split into two polygons
      bound = "AND (ST_INTERSECTS(cluster_point,ST_TRANSFORM(ST_SETSRID(ST_MakeBox2D(ST_POINT(-180,#{params[:swlat]}), ST_POINT(#{params[:nelng]},#{params[:nelat]})),4326),900913)) OR ST_INTERSECTS(cluster_point,ST_TRANSFORM(ST_SETSRID(ST_MakeBox2D(ST_POINT(#{params[:swlng]},#{params[:swlat]}), ST_POINT(180,#{params[:nelat]})),4326),900913)))"
    end
    types = {}
    Cluster.select("type_id, parent_id, SUM(count) as count").joins(:type).group("type_id,parent_id").
                        where("zoom = #{g} AND type_id IS NOT NULL AND (category_mask & #{cat_mask})>0 #{mfilter} #{bound}").each{ |t|
      types[t.type_id] = 0 if types[t.type_id].nil?
      types[t.type_id] += t.count
      # FIXME: doesn't deal properly with more than a single generation, would need to find our parents' parents
      # (grandparents) and so on, and increment those too!
      types[t.parent_id] = 0 if types[t.parent_id].nil?
      types[t.parent_id] += t.count
    }
    log_api_request("api/locations/cluster_types",types.length)
    respond_to do |format|
      format.json { render json: types.collect{ |id,n| {:id => id, :n => n} } }
    end
  end

  def cluster
    mfilter = ""
    if params[:muni].present? and params[:muni].to_i == 1
      mfilter = ""
    elsif params[:muni].present? and params[:muni].to_i == 0
      mfilter = "AND NOT muni"
    end
    tfilter = "AND type_id IS NULL"
    if params[:t].present?
      type = Type.find(params[:t])
      tids = ([type.id] + type.all_children.collect{ |c| c.id }).compact.uniq
      tfilter = "AND type_id IN (#{tids.join(",")})"
    end
    g = params[:grid].present? ? params[:grid].to_i : 2
    g = 12 if g > 12
    if [params[:nelat],params[:nelng],params[:swlat],params[:swlng]].any? { |e| e.nil? }
      bound = ""
    elsif params[:swlng].to_f < params[:nelng].to_f
      bound = "AND ST_INTERSECTS(polygon,ST_TRANSFORM(ST_SETSRID(ST_MakeBox2D(ST_POINT(#{params[:swlng]},#{params[:swlat]}), ST_POINT(#{params[:nelng]},#{params[:nelat]})),4326),900913))"
    else # map spans -180 | 180 seam, split into two polygons
      bound = "AND (ST_INTERSECTS(polygon,ST_TRANSFORM(ST_SETSRID(ST_MakeBox2D(ST_POINT(-180,#{params[:swlat]}), ST_POINT(#{params[:nelng]},#{params[:nelat]})),4326),900913)) OR ST_INTERSECTS(cluster_point,ST_TRANSFORM(ST_SETSRID(ST_MakeBox2D(ST_POINT(#{params[:swlng]},#{params[:swlat]}), ST_POINT(180,#{params[:nelat]})),4326),900913)))"
    end
    
    @clusters = Cluster.select("SUM(count*ST_X(cluster_point))/SUM(count) as center_x,
                                SUM(count*ST_Y(cluster_point))/SUM(count) as center_y,
                                SUM(count) as count").group("grid_point").where("zoom = #{g} #{mfilter} #{tfilter} #{bound}")
                                
    earth_radius = 6378137.0
    earth_circum = 2.0*Math::PI*earth_radius
    
    # Conversion SRID 4326 <-> 900913
    # x = (lng/360)*earth_circum
    # lng = x*(360/earth_circum)
    # y = Math.log(Math.tan((lat+90)*(Math::PI/360)))*earth_radius
    # lat = 90-(Math.atan2(1,Math.exp(y/earth_radius))*(360/Math::PI))
    
    # FIXME: calc pixel distances between cluster positions, merge as necessary
    @clusters.collect!{ |c|
      v = {}
      
      # make single cluster at z = 0 snap to middle of map (optional)
      if g == 0
        v[:lat] = 0
        v[:lng] = 0
      else      
        v[:lat] = 90-(Math.atan2(1,Math.exp(c.center_y.to_f/earth_radius))*(360/Math::PI))
        v[:lng] = c.center_x.to_f*(360/earth_circum)
      end
      v[:n] = c.count
      v[:title] = number_to_human(c.count)
      v[:marker_anchor] = [0,0]
      pct = [[(Math.log10(c.count).round+2)*10,30].max,100].min
      v[:picture] = "/icons/orangedot#{pct}.png"
      v[:width] = pct
      v[:height] = pct
      v[:pct] = pct 
      v
    }
    log_api_request("api/locations/cluster",@clusters.length)
    respond_to do |format|
      format.json { render json: @clusters }
    end
  end

  def nearby
    max_n = 100
    offset_n = params[:offset].present? ? params[:offset].to_i : 0
    if params[:c].blank?
      cat_mask = array_to_mask(["human","freegan"],Type::Categories)
    else
      cat_mask = array_to_mask(params[:c].split(/,/),Type::Categories)
    end
    cfilter = "(bit_or(t.category_mask) & #{cat_mask})>0"
    mfilter = (params[:muni].present? and params[:muni].to_i == 1) ? "" : "AND NOT muni"
    sorted = "1 as sort"
    # FIXME: would be easy to allow t to be an array of types
    if params[:t].present?
      type = Type.find(params[:t])
      tids = ([type.id] + type.all_children.collect{ |c| c.id }).compact.uniq
      sorted = "CASE WHEN array_agg(t.id) @> ARRAY[#{tids.join(",")}] THEN 0 ELSE 1 END as sort"
    end
    unless params[:lat].present? and params[:lng].present?
      # error!
      return
    end
    dist = "ST_DISTANCE(ST_SETSRID(ST_POINT(#{params[:lng]},#{params[:lat]}),4326),l.location)"
    max_distance = 100000
    dfilter = "#{dist} < #{max_distance}" # must be within 100k!
    if (Import.count == 0)
      ifilter = "(import_id IS NULL)"
    else
      ifilter = "(import_id IS NULL OR import_id IN (#{Import.where("autoload #{mfilter}").collect{ |i| i.id }.join(",")}))"
    end
    i18n_name_field = I18n.locale != :en ? "t.#{I18n.locale.to_s.tr("-","_")}_name," : ""
    # FIXME: name doesn't include other types
    r = ActiveRecord::Base.connection.execute("SELECT l.id, l.lat, l.lng, l.unverified, l.type_ids as types,
      #{dist} as distance, l.description, l.author, l.type_others,
      array_agg(t.parent_id) as parent_types,
      string_agg(coalesce(#{i18n_name_field}t.name),',') AS name,
      #{sorted} FROM locations l, types t
      WHERE t.id=ANY(l.type_ids) AND #{[dfilter,ifilter].compact.join(" AND ")}
      GROUP BY l.id, l.lat, l.lng, l.unverified HAVING #{[cfilter].compact.join(" AND ")} ORDER BY distance ASC, sort
      LIMIT #{max_n} OFFSET #{offset_n}");
    @markers = r.collect{ |row|
      row["type_others"] = row["type_others"].tr('{}','').split(/,/).reject{ |x| x == "NULL" }
      row["parent_types"] = row["parent_types"].tr('{}','').split(/,/).reject{ |x| x == "NULL" }.collect{ |e| e.to_i }
      row["types"] = row["types"].tr('{}','').split(/,/).reject{ |x| x == "NULL" }.collect{ |e| e.to_i }
      if row["name"].nil? or row["name"].strip == ""
        name = "Unknown"
      else
        t = row["name"].split(/,/) + row["type_others"]
        if t.length == 2
          name = "#{t[0]} & #{t[1]}"
        elsif t.length > 2
          name = "#{t[0]} & Others"
        else
          name = t[0]
        end
      end
      {:title => name, :location_id => row["id"].to_i,
       :lat => row["lat"].to_f, :lng => row["lng"].to_f,
       :distance => row["distance"].to_f.round,
       :description => row["description"], :author => row["author"]
      }
    } unless r.nil?
    log_api_request("api/locations/nearby",@markers.length)
    respond_to do |format|
      format.json { render json: @markers }
    end
  end

  # Currently keeps max_n markers, and displays filtered out markers as translucent grey.
  # Unverified no longer has its own color.
  def markers
    max_n = 1000
    if params[:c].blank?
      cat_mask = array_to_mask(["human","freegan"],Type::Categories)
    else
      cat_mask = array_to_mask(params[:c].split(/,/),Type::Categories)
    end
    cfilter = "(bit_or(t.category_mask) & #{cat_mask})>0"
    mfilter = (params[:muni].present? and params[:muni].to_i == 1) ? "" : "AND NOT muni"
    sorted = "1 as sort"
    # FIXME: would be easy to allow t to be an array of types
    if params[:t].present?
      type = Type.find(params[:t])
      tids = ([type.id] + type.all_children.collect{ |c| c.id }).compact.uniq
      sorted = "CASE WHEN array_agg(t.id) @> ARRAY[#{tids.join(",")}] THEN 0 ELSE 1 END as sort"
    end
    bound = [params[:nelat],params[:nelng],params[:swlat],params[:swlng]].any? { |e| e.nil? } ? "" :
      "ST_INTERSECTS(location,ST_SETSRID(ST_MakeBox2D(ST_POINT(#{params[:swlng]},#{params[:swlat]}),
                                                     ST_POINT(#{params[:nelng]},#{params[:nelat]})),4326))"
    if (Import.count == 0)
      ifilter = "(import_id IS NULL)"
    else      
      ifilter = "(import_id IS NULL OR import_id IN (#{Import.where("autoload #{mfilter}").collect{ |i| i.id }.join(",")}))"
    end
    r = ActiveRecord::Base.connection.select_one("SELECT count(*) FROM locations l, types t WHERE t.id=ANY(l.type_ids) AND #{[bound,ifilter].compact.join(" AND ")} GROUP BY l.id HAVING #{[cfilter].compact.join(" AND ")}");
    found_n = r["count"].to_i unless r.nil?
    i18n_name_field = I18n.locale != :en ? "types.#{I18n.locale.to_s.tr("-","_")}_name," : ""
    r = ActiveRecord::Base.connection.execute("SELECT l.id, l.lat, l.lng, l.unverified, l.type_ids as types, l.type_others,
      array_agg(t.parent_id) as parent_types, string_agg(coalesce(#{i18n_name_field}t.name),',') AS name, #{sorted}
      FROM locations l, types t
      WHERE t.id=ANY(l.type_ids) AND #{[bound,ifilter].compact.join(" AND ")}
      GROUP BY l.id, l.lat, l.lng, l.unverified HAVING #{[cfilter].compact.join(" AND ")} ORDER BY sort LIMIT #{max_n}");
    @markers = r.collect{ |row|
      row["type_others"] = row["type_others"].tr('{}','').split(/,/).reject{ |x| x == "NULL" }
      row["parent_types"] = row["parent_types"].tr('{}','').split(/,/).reject{ |x| x == "NULL" }.collect{ |e| e.to_i }
      row["types"] = row["types"].tr('{}','').split(/,/).reject{ |x| x == "NULL" }.collect{ |e| e.to_i }
      if row["name"].nil? or row["name"].strip == ""
        name = "Unknown"
      else
        t = row["name"].split(/,/) + row["type_others"]
        if t.length == 2
          name = "#{t[0]} & #{t[1]}"
        elsif t.length > 2
          name = "#{t[0]} & Others"
        else
          name = t[0]
        end
      end
      {:title => name, :location_id => row["id"], :lat => row["lat"], :lng => row["lng"],
       :picture => "/icons/smdot_t1_red.png",:width => 17, :height => 17,
       :marker_anchor => [0,0], :types => row["types"],
       :parent_types => row["parent_types"]
      }
    } unless r.nil?
    @markers.unshift(max_n)
    @markers.unshift(found_n)
    log_api_request("api/locations/markers",@markers.length-2)
    respond_to do |format|
      format.json { render json: @markers }
    end
  end

  def marker
     id = params[:id].to_i
     i18n_name_field = I18n.locale != :en ? "t.#{I18n.locale.to_s.tr("-","_")}_name," : ""
     r = ActiveRecord::Base.connection.execute("SELECT l.id, l.lat, l.lng, l.unverified, array_agg(t.id) as types,
      array_agg(t.parent_id) as parent_types, l.type_others,
      string_agg(coalesce(#{i18n_name_field}t.name,lt.type_other),',') as name
      FROM locations l, types t
      WHERE t.id=ANY(l.type_ids) AND l.id=#{id}
      GROUP BY l.id, l.lat, l.lng, l.unverified");
    @markers = r.collect{ |row|
      row["type_others"] = row["type_others"].tr('{}','').split(/,/).reject{ |x| x == "NULL" }
      row["parent_types"] = row["parent_types"].tr('{}','').split(/,/).reject{ |x| x == "NULL" }.collect{ |e| e.to_i }
      row["types"] = row["types"].tr('{}','').split(/,/).reject{ |x| x == "NULL" }.collect{ |e| e.to_i }
      if row["name"].nil? or row["name"].strip == ""
        name = "Unknown"
      else
        t = row["name"].split(/,/) + row["type_others"]
        if t.length == 2
          name = "#{t[0]} & #{t[1]}"
        elsif t.length > 2
          name = "#{t[0]} & Others"
        else
          name = t[0]
        end
      end
      {:title => name, :location_id => row["id"], :lat => row["lat"], :lng => row["lng"], 
       :picture => "/icons/smdot_t1_red.png",:width => 17, :height => 17, :parent_types => row["parent_types"],
       :marker_anchor => [0,0], :n => 1, :types => row["types"]}
    } unless r.nil?
    log_api_request("api/locations/marker",1)
    respond_to do |format|
      format.json { render json: @markers }
    end
  end

end
