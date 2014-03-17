class LocationsController < ApplicationController
  before_filter :authenticate_user!, :only => [:destroy,:enroute]
  before_filter :prepare_for_mobile, :except => [:cluster,:markers,:marker,:data,:infobox]
  authorize_resource :only => [:destroy,:enroute]

  def expire_things
    expire_fragment "pages_data_type_summary_table"
    expire_fragment "pages_about_stats"
  end

	# Note: intersect on center_point so that count reflects counts shown on map
  def cluster_types
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
                        where("zoom = #{g} AND type_id IS NOT NULL #{mfilter} #{bound}").each{ |t|
      types[t.type_id] = 0 if types[t.type_id].nil?
      types[t.type_id] += t.count
      # FIXME: doesn't deal properly with more than a single generation, would need to find our parents' parents
      # (grandparents) and so on, and increment those too!
      types[t.parent_id] = 0 if types[t.parent_id].nil?
      types[t.parent_id] += t.count
    }
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
    respond_to do |format|
      format.json { render json: @clusters }
    end
  end

  # Currently keeps max_n markers, and displays filtered out markers as translucent grey.
  # Unverified no longer has its own color.
  def markers
    max_n = 1000
    mfilter = (params[:muni].present? and params[:muni].to_i == 1) ? "" : "AND NOT muni"
    tfilter = nil
    sorted = "1 as sort"
    # FIXME: would be easy to allow t to be an array of types
    if params[:t].present?
      type = Type.find(params[:t])
      tids = ([type.id] + type.all_children.collect{ |c| c.id }).compact.uniq
      tfilter = "AND type_id IN (#{tids.join(",")})"
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
    r = ActiveRecord::Base.connection.select_one("SELECT count(*) from locations l
      WHERE #{[bound,ifilter].compact.join(" AND ")}");
    found_n = r["count"].to_i unless r.nil? 
    r = ActiveRecord::Base.connection.execute("SELECT l.id, l.lat, l.lng, l.unverified, array_agg(t.id) as types,
      array_agg(t.parent_id) as parent_types, string_agg(coalesce(t.name,lt.type_other),',') AS name, #{sorted} FROM locations l,
      locations_types lt LEFT OUTER JOIN types t ON lt.type_id=t.id
      WHERE lt.location_id=l.id AND #{[bound,ifilter].compact.join(" AND ")} 
      GROUP BY l.id, l.lat, l.lng, l.unverified ORDER BY sort LIMIT #{max_n}");
    @markers = r.collect{ |row|
      if row["name"].nil? or row["name"].strip == ""
        name = "Unknown"
      else
        t = row["name"].split(/,/)
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
       :marker_anchor => [0,0], :types => row["types"].tr('{}','').split(/,/).collect{ |e| e.to_i },
       :parent_types => row["parent_types"].tr('{}','').split(/,/).reject{ |x| x == "NULL" }.collect{ |e| e.to_i }
      }
    } unless r.nil?
    @markers.unshift(max_n)
    @markers.unshift(found_n)
    respond_to do |format|
      format.json { render json: @markers }
    end
  end

  def marker
     id = params[:id].to_i
     r = ActiveRecord::Base.connection.execute("SELECT l.id, l.lat, l.lng, l.unverified, array_agg(t.id) as types,
      array_agg(t.parent_id) as parent_types,
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
          name = "#{t[0]} & #{t[1]}"
        elsif t.length > 2
          name = "#{t[0]} & Others"
        else
          name = t[0]
        end
      end
      {:title => name, :location_id => row["id"], :lat => row["lat"], :lng => row["lng"], 
       :picture => "/icons/smdot_t1_red.png",:width => 17, :height => 17, :parent_types => row["parent_types"].tr('{}','').split(/,/).reject{ |x| x == "NULL" }.collect{ |e| e.to_i },
       :marker_anchor => [0,0], :n => 1, :types => row["types"].tr('{}','').split(/,/).collect{ |e| e.to_i } }
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
                     author, import_id, locations.created_at, locations.updated_at, muni').
             where([bound,mfilter].compact.join(" AND ")).
             group("locations.id, imports.muni").limit(max_n)
    respond_to do |format|
      format.json { render json: @locations }
      format.csv { 
        csv_data = CSV.generate do |csv|
          cols = ["id","lat","lng","unverified","description","season_start","season_stop",
                  "no_season","quality_rating","yield_rating","author","address","created_at","updated_at",
                  "access","import_link","muni","name"]
          csv << cols
          @locations.each{ |l|
          
          	quality_rating = Location.find(l.id).mean_quality_rating
          	yield_rating = Location.find(l.id).mean_yield_rating
          	
            csv << [l.id,l.lat,l.lng,l.unverified,l.description,
            				l.season_start.nil? ? nil : Location::Months[l.season_start],
                    l.season_stop.nil? ? nil : Location::Months[l.season_stop],
                    l.no_season,
                    quality_rating.nil? ? nil : Location::Ratings[quality_rating],
                    yield_rating.nil? ? nil : Location::Ratings[yield_rating],
                    l.author,l.address,l.created_at,l.updated_at,
                    l.access.nil? ? nil : Location::AccessShort[l.access],l.import_id.nil? ? nil : "http://fallingfruit.org/imports/#{l.import_id}",
                    l.import_id.nil? ? false : (l.muni ? true : false), 
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
    @perma = {}
    @perma[:zoom] = params[:z].to_i if params[:z].present?
    @perma[:lat] = params[:y].to_f if params[:y].present?
    @perma[:lng] = params[:x].to_f if params[:x].present?
    @perma[:muni] = params[:m] == "true" if params[:m].present?
    @perma[:labels] = params[:l] == "true" if params[:l].present?
    @perma[:type] = params[:t] if params[:t].present?
    @perma[:center_mark] = params[:center_mark] == "true" if params[:center_mark].present?
    @perma[:center_radius] = params[:circle].to_i if params[:circle].present?
    @type = params[:f].present? ? Type.find(params[:f]) : nil
    @width = params[:width].present? ? params[:width].to_i : 640
    @height = params[:height].present? ? params[:height].to_i : 600
    respond_to do |format|
      format.html { render :layout => false } # embed.html.erb
    end
  end

  # GET /dumpsters
  def freegan_index
    @freegan = true
    @type = Type.find(843)
    params[:f] = @type.id
    index and return
  end

  # GET /locations/home
  def home
    prepare_for_sidebar if user_signed_in? and current_user.is? :admin
    index
  end

  # GET /locations
  # GET /locations.json
  def index
    @perma = {}
    @perma[:zoom] = params[:z].to_i if params[:z].present?
    @perma[:lat] = params[:y].to_f if params[:y].present?
    @perma[:lng] = params[:x].to_f if params[:x].present?
    @perma[:muni] = params[:m] == "true" if params[:m].present?
    @perma[:labels] = params[:l] == "true" if params[:l].present?
    @perma[:type] = params[:t] if params[:t].present?
    unless @freegan
      @type = params[:f].present? ? Type.find(params[:f]) : nil
    end
    respond_to do |format|
      format.html { render "index" }# index.html.erb
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
    p = 0
    lts = []
     params[:types].split(/,/).collect{ |e| e[/^([^\[]*)/].strip.capitalize }.uniq.each{ |type_name|
      lt = LocationsType.new
      t = Type.where("name = ?",type_name.strip).first
      if t.nil? 
        lt.type_other = type_name
      else
        lt.type = t
      end
      lt.position = p
      p += 1
      lts.push lt
    } if params[:types].present?

    @location = Location.new(params[:location])
    @location.locations_types += lts
    @location.user = current_user if user_signed_in?

    # create an observation if necessary
    @obs = nil
    if params[:quality_rating].present? or params[:yield_rating].present?
      @obs = Observation.new
      @obs.quality_rating = params[:quality_rating].to_i unless params[:quality_rating].blank?
      @obs.yield_rating = params[:yield_rating].to_i unless params[:yield_rating].blank?
      @obs.fruiting = params[:fruiting].to_i unless params[:fruiting].blank?
      if params[:observed_on].empty?
        @obs.observed_on = Date.today
      else
        @obs.observed_on = Timeliness.parse(params[:observed_on], :format => 'mm/dd/yyyy')
      end
      @obs.location = @location
      @obs.user = current_user if user_signed_in?
      @obs.author = @location.author
    end

    respond_to do |format|
      test = user_signed_in? ? true : verify_recaptcha(:model => @location, 
                                                       :message => "ReCAPCHA error!")
      if test and @location.save and (@obs.nil? or @obs.save)
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

    # prevent normal users from changing author
    params[:location][:author] = @location.author unless user_signed_in? and current_user.is? :admin

    p = 0
    lts = []
    @location.locations_types.collect{ |lt| LocationsType.delete(lt.id) }
    params[:types].split(/,/).collect{ |e| e[/^([^\[]*)/].strip.capitalize }.uniq.each{ |type_name|
      lt = LocationsType.new
      t = Type.where("name = ?",type_name).first
      if t.nil? 
        lt.type_other = type_name
      else
        lt.type = t
      end
      lt.position = p
      lt.location_id = @location.id
      p += 1
      lts.push lt
    } if params[:types].present?

    lt_update_okay = lts.collect{ |lt| lt.save }.all?

    ApplicationController.cluster_decrement(@location)
    respond_to do |format|
      test = user_signed_in? ? true : verify_recaptcha(:model => @location, 
                                                       :message => "ReCAPCHA error!")
      if test and @location.update_attributes(params[:location]) and lt_update_okay
        
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
      @route.name = "Route ##{Route.count + 1}"
      @route.user = current_user
      @route.access_key = Digest::MD5.hexdigest(rand.to_s)
      @route.is_public = true
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

  private

  def prepare_for_sidebar
    rangeq = current_user.range.nil? ? "" : "AND ST_INTERSECTS(l.location,(SELECT range FROM users u2 WHERE u2.id=#{current_user.id}))"
    r = ActiveRecord::Base.connection.execute("SELECT string_agg(coalesce(t.name,lt.type_other),',') as type_title,
      extract(days from (NOW()-c.created_at)) as days_ago, c.location_id, c.user_id, c.description, c.remote_ip, l.city, l.state, l.country, l.lat, l.lng,
      array_agg(lt.position) as positions
      FROM changes c, locations l, locations_types lt left outer join types t on lt.type_id=t.id
      WHERE lt.location_id=l.id AND l.id=c.location_id #{rangeq}
      GROUP BY l.id, c.location_id, c.user_id, c.description, c.remote_ip, c.created_at ORDER BY c.created_at DESC LIMIT 100");
    @changes = r.collect{ |row| row }
    @mine = Observation.joins(:location).select('max(observations.created_at) as created_at,observations.user_id,location_id,lat,lng').
      where("observations.user_id = ?",current_user.id).group("location_id,observations.user_id,lat,lng,observations.created_at").order('observations.created_at desc')
    @routes = Route.where("user_id = ?",current_user.id)
    @zoom_to_polygon = current_user.range.nil? ? nil : current_user.range
    @zoom_to_circle = nil
    @show_sidebar = true
    # FIXME: zoom circle!
  end
end
