class LocationsController < ApplicationController
  before_filter :authenticate_user!, :only => [:destroy,:enroute]
  before_filter :prepare_for_mobile, :except => [:cluster,:markers,:marker,:data,:infobox]
  authorize_resource :only => [:destroy,:enroute]

  def expire_things
    expire_fragment "pages_data_type_summary_table"
    expire_fragment "pages_about_stats"
  end

  def cluster
    mfilter = ""
    if params[:muni].present? and params[:muni].to_i == 1
      mfilter = ""
    elsif params[:muni].present? and params[:muni].to_i == 0
      mfilter = "AND NOT muni"
    end
    g = params[:grid].present? ? params[:grid].to_i : 1
    g = 12 if g > 12
    bound = [params[:nelat],params[:nelng],params[:swlat],params[:swlng]].any? { |e| e.nil? } ? "" : 
      "AND ST_INTERSECTS(polygon,ST_TRANSFORM(ST_SETSRID(ST_MakeBox2D(ST_POINT(#{params[:swlng]},#{params[:swlat]}),
                                                         ST_POINT(#{params[:nelng]},#{params[:nelat]})),4326),900913))"
    
    @clusters = Cluster.select("SUM(count*ST_X(cluster_point))/SUM(count) as center_x,
                                SUM(count*ST_Y(cluster_point))/SUM(count) as center_y,
                                SUM(count) as count").group("grid_point").where("zoom = #{g} #{mfilter} #{bound}")
    
    #@minmax = Cluster.select("MIN(count) as min_count, MAX(count) as max_count").where("zoom = #{g} #{mfilter}").shift

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
      #pct = (c.count-@minmax.min_count.to_f)/(@minmax.max_count.to_f-@minmax.min_count.to_f)
      #pct = (10.0*pct).round * 10
      pct = [[(Math.log10(c.count).round+2)*10,30].max,100].min
      v[:picture] = "/icons/orangedot#{pct}.png"
      v[:width] = pct
      v[:height] = pct
      v[:pct] = pct 
      v
    }
    respond_to do |format|
      format.json { render json: @clusters }
    end
  end

  def markers
    max_n = 500
    mfilter = (params[:muni].present? and params[:muni].to_i == 1) ? "" : "AND NOT muni"
    bound = [params[:nelat],params[:nelng],params[:swlat],params[:swlng]].any? { |e| e.nil? } ? "" :
      "ST_INTERSECTS(location,ST_SETSRID(ST_MakeBox2D(ST_POINT(#{params[:swlng]},#{params[:swlat]}),
                                                     ST_POINT(#{params[:nelng]},#{params[:nelat]})),4326))"
    ifilter = "(import_id IS NULL OR import_id IN (#{Import.where("autoload #{mfilter}").collect{ |i| i.id }.join(",")}))"
    r = ActiveRecord::Base.connection.select_one("SELECT count(*) from locations l
      WHERE #{[bound,ifilter].compact.join(" AND ")}");
    found_n = r["count"].to_i unless r.nil? 
    r = ActiveRecord::Base.connection.execute("SELECT l.id, l.lat, l.lng, l.unverified, 
      string_agg(coalesce(t.name,lt.type_other),',') as name from locations l, 
      locations_types lt left outer join types t on lt.type_id=t.id
      WHERE lt.location_id=l.id AND #{[bound,ifilter].compact.join(" AND ")} 
      GROUP BY l.id, l.lat, l.lng, l.unverified LIMIT #{max_n}");
    @markers = r.collect{ |row|
      if row["name"].nil? or row["name"].strip == ""
        name = "Unknown"
      else
        t = row["name"].split(/,/)
        if t.length == 2
          name = "#{t[0]} and #{t[1]}"
        elsif t.length > 2
          name = "#{t[0]} & Others"
        else
          name = t[0]
        end
      end
      {:title => name, :location_id => row["id"], :lat => row["lat"], :lng => row["lng"], 
       :picture => (row["unverified"] == 't') ? "/icons/smdot_t1_gray_light.png" : "/icons/smdot_t1_red.png",:width => 17, :height => 17,
       :marker_anchor => [0,0], :n => found_n }
    } unless r.nil?
    respond_to do |format|
      format.json { render json: @markers }
    end
  end

  def marker
     id = params[:id].to_i
     r = ActiveRecord::Base.connection.execute("SELECT l.id, l.lat, l.lng, l.unverified, 
      string_agg(coalesce(t.name,lt.type_other),',') as name from locations l, 
      locations_types lt left outer join types t on lt.type_id=t.id
      WHERE lt.location_id=l.id AND l.id=#{id}
      GROUP BY l.id, l.lat, l.lng, l.unverified");
    @markers = r.collect{ |row|
      if row["name"].nil? or row["name"].strip == ""
        name = "Unknown"
      else
        t = row["name"].split(/,/)
        if t.length == 2
          name = "#{t[0]} and #{t[1]}"
        elsif t.length > 2
          name = "#{t[0]} & Others"
        else
          name = t[0]
        end
      end
      {:title => name, :location_id => row["id"], :lat => row["lat"], :lng => row["lng"], 
       :picture => (row["unverified"] == 't') ? "/icons/smdot_t1_gray_light.png" : "/icons/smdot_t1_red.png",:width => 17, :height => 17,
       :marker_anchor => [0,0], :n => 1 }
    } unless r.nil?
    respond_to do |format|
      format.json { render json: @markers }
    end
  end

  def data
    max_n = 500
    mfilter = (params[:muni].present? and params[:muni].to_i == 1) ? nil : "NOT muni"
    bound = [params[:nelat],params[:nelng],params[:swlat],params[:swlng]].any? { |e| e.nil? } ? "" :
      "ST_INTERSECTS(location,ST_SETSRID(ST_MakeBox2D(ST_POINT(#{params[:swlng]},#{params[:swlat]}),
                                                     ST_POINT(#{params[:nelng]},#{params[:nelat]})),4326))"
    @locations = Location.joins("INNER JOIN locations_types ON locations_types.location_id=locations.id").
             joins("LEFT OUTER JOIN types ON locations_types.type_id=types.id").
             joins("LEFT OUTER JOIN imports ON locations.import_id=imports.id").
             select('ARRAY_AGG(COALESCE(types.name,locations_types.type_other)) as name, locations.id as id, 
                     description, lat, lng, address, season_start, season_stop, no_season, access, unverified, 
                     yield_rating, quality_rating, author, import_id, locations.created_at, locations.updated_at').
             where([bound,mfilter].compact.join(" AND ")).
             group("locations.id").limit(max_n)
    respond_to do |format|
      format.json { render json: @locations }
      format.csv { 
        csv_data = CSV.generate do |csv|
          cols = ["id","lat","lng","unverified","description","season_start","season_stop",
                  "no_season","author","address","created_at","updated_at",
                  "quality_rating","yield_rating","access","import_link","name"]
          csv << cols
          @locations.each{ |l|
            csv << [l.id,l.lat,l.lng,l.unverified,l.description,l.season_start.nil? ? nil : Location::Months[l.season_start],
                    l.season_stop.nil? ? nil : Location::Months[l.season_stop],l.no_season,l.author,l.address,l.created_at,l.updated_at,
                    l.quality_rating.nil? ? nil : Location::Ratings[l.quality_rating],l.yield_rating.nil? ? nil : Location::Ratings[l.yield_rating],
                    l.access.nil? ? nil : Location::AccessShort[l.access],l.import_id.nil? ? nil : "http://fallingfruit.org/imports/#{l.import_id}",
                    l.name]
          }
        end
        send_data(csv_data,:type => 'text/csv; charset=utf-8; header=present', :filename => 'data.csv')
      }
    end
  end

  def import
    if request.post? && params[:csv].present?
      infile = params[:csv].tempfile
      import = Import.new(params[:import])
      import.save
      filepath = File.join("public","import","#{import.id}.csv")
      FileUtils.cp infile.path, filepath
      FileUtils.chmod 0666, filepath
      flash[:notice] = "Import #{import.id} queued for processing..."
    end
  end      

  def infobox
    @location = Location.find(params[:id])
    respond_to do |format|
      format.html { render :partial => "/locations/infowindow", :locals => {:location => @location} }
      format.json { 
        @location["types"] = @location.locations_types
        render json: @location 
      }
    end
  end

  def embed
    @perma = nil
    if params[:z].present? and params[:y].present? and params[:x].present? and params[:m].present?
      @perma = {:zoom => params[:z].to_i, :lat => params[:y].to_f, :lng => params[:x].to_f,
                :muni => params[:m] == "true", :type => params[:t]}
    end
    @width = params[:width].present? ? params[:width].to_i : 500
    @height = params[:height].present? ? params[:height].to_i : 500
    respond_to do |format|
      format.html { render :layout => false } # embed.html.erb
    end
  end

  # GET /locations
  # GET /locations.json
  def index
    @perma = nil
    if params[:z].present? and params[:y].present? and params[:x].present? and params[:m].present?
      @perma = {:zoom => params[:z].to_i, :lat => params[:y].to_f, :lng => params[:x].to_f,
                :muni => params[:m] == "true", :type => params[:t]}
    end
    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @locations }
      format.csv { render :csv => @locations }
    end
  end

  def show
    @location = Location.find(params[:id])
    respond_to do |format|
      format.html
      format.mobile
    end
  end

  # GET /locations/new
  # GET /locations/new.json
  def new
    @location = Location.new
    @lat = nil
    @lng = nil
    unless params[:lat].nil? or params[:lng].nil?
      @lat = params[:lat].to_f
      @lng = params[:lng].to_f
      @location.lat = @lat
      @location.lng = @lng
    end
    respond_to do |format|
      format.html # new.html.erb
      format.mobile
    end
  end

  # GET /locations/1/edit
  def edit
    @location = Location.find(params[:id])
    @lat = @location.lat
    @lng = @location.lng
    respond_to do |format|
      format.html
      format.mobile
    end
  end

  # POST /locations
  # POST /locations.json
  def create
    unless params[:location].nil? or params[:location][:locations_types].nil?
      lt_seen = {}
      p = 0
      lts = params[:location][:locations_types].collect{ |dc,data| 
        lt = LocationsType.new
        unless data[:type_id].nil? or (data[:type_id].strip == "")
          lt.type_id = data[:type_id]
        else
          lt.type_other = data[:type_other] unless data[:type_other].nil? or (data[:type_other].strip == "") or
                          data[:type_other] =~ /something not in the list/
        end
        k = lt.type_id.nil? ? lt.type_other : lt.type_id
        if lt.type_id.nil? and lt.type_other.nil?
          lt = nil
        elsif !lt_seen[k].nil?
          lt = nil
        else
          lt_seen[k] = true
        end
        lt.position = p
        p += 1
        lt
      }.compact
      params[:location].delete(:locations_types)
    end
    @location = Location.new(params[:location])
    @lat = @location.lat
    @lng = @location.lng
    @location.locations_types += lts unless lts.nil?
    respond_to do |format|
      test = user_signed_in? ? true : verify_recaptcha(:model => @location, 
                                                       :message => "ReCAPCHA error!")
      if test and @location.save
        ApplicationController.cluster_increment(@location)
        log_changes(@location,"added")
        expire_things
        if params[:create_another].present? and params[:create_another].to_i == 1
          format.html { redirect_to new_location_path, notice: 'Location was successfully created.' }
          format.mobile { redirect_to new_location_path, notice: 'Location was successfully created.' }
        else
          format.html { redirect_to @location, notice: 'Location was successfully created.' }
          format.mobile { redirect_to @location, notice: 'Location was successfully created.' }
        end
      else
        format.html { render action: "new" }
        format.mobile { render action: "new" }
      end
    end
  end

  # PUT /locations/1
  # PUT /locations/1.json
  def update
    @location = Location.find(params[:id])
    @lat = @location.lat
    @lng = @location.lng

    # prevent normal users from changing author
    params[:location][:author] = @location.author unless user_signed_in? and current_user.is? :admin

    # manually update location types :/
    unless params[:location].nil? or params[:location][:locations_types].nil?
      # delete existing types before adding new stuff
      @location.locations_types.collect{ |lt| LocationsType.delete(lt.id) }
      # add/update types
      lt_seen = {}
      p = 0
      params[:location][:locations_types].each{ |dc,data|
        lt = LocationsType.new
        unless data[:type_id].nil? or (data[:type_id].strip == "")
          lt.type_id = data[:type_id]
        else
          lt.type_other = data[:type_other] unless data[:type_other].nil? or (data[:type_other].strip == "")
        end
        next if lt.type_id.nil? and lt.type_other.nil?
        k = lt.type_id.nil? ? lt.type_other : lt.type_id
        next unless lt_seen[k].nil?
        lt_seen[k] = true
        lt.location_id = @location.id   
        lt.position = p
        lt.save
        p += 1
      }
      params[:location].delete(:locations_types)
    end

    ApplicationController.cluster_decrement(@location)
    respond_to do |format|
      test = user_signed_in? ? true : verify_recaptcha(:model => @location, 
                                                       :message => "ReCAPCHA error!")
     
      if test and @location.update_attributes(params[:location])
        log_changes(@location,"edited")
        ApplicationController.cluster_increment(@location)
        expire_things
        format.html { redirect_to @location, notice: 'Location was successfully updated.' }
        format.mobile { redirect_to @location, notice: 'Location was successfully updated.' }
      else
        format.html { render action: "edit" }
        format.mobile { render action: "edit" }
      end
    end
  end

  # DELETE /locations/1
  # DELETE /locations/1.json
  def destroy
    @location = Location.find(params[:id])
    ApplicationController.cluster_decrement(@location)
    @location.destroy
    LocationsType.where("location_id=#{params[:id]}").each{ |lt|
      lt.destroy
    }
    expire_things
    log_changes(nil,"1 location deleted")
    respond_to do |format|
      format.html { redirect_to locations_url }
      format.mobile { redirect_to locations_url }
    end
  end

  def enroute
    @location = Location.find(params[:id])
    @route = nil
    if params[:route_id].to_i < 0
      @route = Route.new
      @route.name = "Unnamed Route"
      @route.user = current_user
      @route.save
      lr = LocationsRoute.new
      lr.route = @route
      lr.location = @location
      lr.save
    else
      @route = Route.find(params[:route_id])
      lr = LocationsRoute.where("route_id = ? AND location_id = ?",@route.id,@location.id)
      if lr.nil? or lr.length == 0
        lr = LocationsRoute.new
        lr.route = @route
        lr.location_id = @location.id
        lr.save
      else
        lr.each{ |e| e.destroy }
      end
    end
    respond_to do |format|
      format.html { redirect_to @route }
    end
  end
end
