class LocationsController < ApplicationController
  before_filter :authenticate_admin!, :only => [:destroy]
  before_filter :prepare_for_mobile, :except => [:cluster,:markers,:marker,:data,:infobox]

  #################### HELPERS #####################

  def expire_things
    expire_fragment "pages_data_type_summary_table"
  end

  def cluster_increment(location)
    muni = (!location.import.nil? and location.import.muni) ? true : false
    mq = muni ? "AND muni" : "AND NOT MUNI"
    found = []
    Cluster.where("ST_INTERSECTS(ST_SETSRID(ST_POINT(#{location.lng},#{location.lat}),4326),polygon) #{mq}").each{ |clust|
      clust.count += 1
      # since the center lat is the arithmetic mean of the bag of points, simply integrate this points' location proportionally
      clust.center_lat = ((clust.count-1).to_f/clust.count.to_f)*clust.center_lat + (1.0/clust.count.to_f)*location.lat
      clust.center_lng = ((clust.count-1).to_f/clust.count.to_f)*clust.center_lng + (1.0/clust.count.to_f)*location.lng
      clust.save
      found << clust.zoom
    }
    cluster_seed(location,(1..15).to_a - found,muni) unless found.length == 15
  end

  def cluster_decrement(location)
    mq = (!location.import.nil? and location.import.muni) ? "AND muni" : "AND NOT muni"
    Cluster.where("ST_INTERSECTS(ST_SETSRID(ST_POINT(#{location.lng},#{location.lat}),4326),polygon) #{mq}").each{ |clust|
      clust.count -= 1
      if(clust.count <= 0)
        clust.destroy
      else
        # since the center lat is the arithmetic mean of the bag of points, simply remove this points' location proportionally
        clust.center_lat = (clust.count.to_f/clust.count.to_f)*clust.center_lat - (1.0/clust.count.to_f)*location.lat
        clust.center_lng = (clust.count.to_f/clust.count.to_f)*clust.center_lng - (1.0/clust.count.to_f)*location.lng
        clust.save
      end
    }
  end

  def cluster_seed(location,zooms,muni)
    zooms.each{ |z| 
      c = Cluster.new
      c.grid_size = 360/(12.0*(2.0**(z-3))) 
      r = ActiveRecord::Base.connection.execute <<-SQL
        SELECT ST_AsText(ST_MakeBox2d(ST_Translate(grid_point,#{c.grid_size/-2.0},#{c.grid_size/-2.0}),
                                      ST_translate(grid_point,#{c.grid_size/2.0},#{c.grid_size/2.0}))) AS poly_wkt, 
               ST_AsText(grid_point) as grid_point_wkt 
        FROM (
          SELECT ST_SnapToGrid(st_setsrid(ST_POINT(#{location.lng},#{location.lat}),4326),#{c.grid_size},#{c.grid_size}) AS grid_point
        ) AS gsub
      SQL
      r.each{ |row|
      c.grid_point = row["grid_point_wkt"]
      c.polygon = row["poly_wkt"]
      c.count = 1
      c.center_lat = location.lat
      c.center_lng = location.lng
      c.zoom = z
      c.method = "grid"
      c.muni = muni
      c.save
      } unless r.nil?
    }
  end

  def log_changes(location,description)
    c = Change.new
    c.location = location
    c.description = description
    c.remote_ip = request.remote_ip
    c.admin = current_admin if admin_signed_in?
    c.save
  end

  def number_to_human(n)
    if n > 999 and n <= 999999
      (n/1000.0).round.to_s + "K"
    elsif n > 999999
      (n/1000000.0).round.to_s + "M"
    else
      n.to_s
    end
  end

  #################### ROUTED METHODS ##################

  def cluster
    mfilter = ""
    if params[:muni].present? and params[:muni].to_i == 1
      mfilter = "AND muni"
    elsif params[:muni].present? and params[:muni].to_i == 0
      mfilter = "AND NOT muni"
    end
    g = params[:grid].present? ? params[:grid].to_i : 1
    g = 15 if g > 15
    bound = [params[:nelat],params[:nelng],params[:swlat],params[:swlng]].any? { |e| e.nil? } ? "" : 
      "AND ST_INTERSECTS(grid_point,ST_GeogFromText('POLYGON((#{params[:nelng].to_f} #{params[:nelat].to_f}, #{params[:swlng].to_f} #{params[:nelat].to_f}, #{params[:swlng].to_f} #{params[:swlat].to_f}, #{params[:nelng].to_f} #{params[:swlat].to_f}, #{params[:nelng].to_f} #{params[:nelat].to_f}))'))"
    total = 0
    @clusters = {}
    Cluster.where("zoom = #{g} #{mfilter} #{bound}").each{ |c|
        if @clusters[c.grid_point].nil?
          @clusters[c.grid_point] = { :n => [c.count],:lat => [c.center_lat],:lng => [c.center_lng] }
        elsif
          @clusters[c.grid_point][:n] << c.count
          @clusters[c.grid_point][:lat] << c.center_lat
          @clusters[c.grid_point][:lng] << c.center_lng 
        end
        total += c.count
    }
    max_pct = nil
    min_pct = nil
    @clusters = @clusters.collect{ |k,v|
      v[:lat] = (0..v[:lat].length-1).collect{ |i| v[:lat][i]*(v[:n][i].to_f/v[:n].sum.to_f) }.sum
      v[:lng] = (0..v[:lng].length-1).collect{ |i| v[:lng][i]*(v[:n][i].to_f/v[:n].sum.to_f) }.sum
      v[:merged] = v[:n].length
      v[:n] = v[:n].sum
      v[:title] = number_to_human(v[:n])
      v[:marker_anchor] = [0,0]
      pct = ((100.0*v[:n].to_f/total)/10.0).round * 10
      max_pct = pct if max_pct.nil? or max_pct < pct
      min_pct = pct if min_pct.nil? or min_pct > pct
      v[:pct] = pct
      v[:picture] = "/icons/bluedot#{pct}.png"
      v[:width] = pct
      v[:height] = pct
      v
    }
    @clusters.collect!{ |v|
      pct = (10.0*(v[:pct]-min_pct).to_f/(max_pct.to_f-min_pct.to_f)).round * 10
      pct = 30 if pct < 30
      pct = 80 if pct == 100
      v[:picture] = "/icons/bluedot#{pct}.png"
      v[:width] = pct
      v[:height] = pct
      v
    }
    respond_to do |format|
      format.json { render json: @clusters }
    end
  end

  def markers
    max_n = 500
    mfilter = (params[:muni].present? and params[:muni].to_i == 1) ? "" : "AND NOT muni"
    bound = [params[:nelat],params[:nelng],params[:swlat],params[:swlng]].any? { |e| e.nil? } ? nil :
      "ST_INTERSECTS(location,ST_GeogFromText('POLYGON((#{params[:nelng].to_f} #{params[:nelat].to_f}, #{params[:swlng].to_f} #{params[:nelat].to_f}, #{params[:swlng].to_f} #{params[:swlat].to_f}, #{params[:nelng].to_f} #{params[:swlat].to_f}, #{params[:nelng].to_f} #{params[:nelat].to_f}))'))"
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
    mfilter = (params[:muni].present? and params[:muni].to_i == 1) ? "" : "AND NOT muni"
    bound = [params[:nelat],params[:nelng],params[:swlat],params[:swlng]].any? { |e| e.nil? } ? nil :
      "ST_INTERSECTS(location,ST_GeogFromText('POLYGON((#{params[:nelng].to_f} #{params[:nelat].to_f}, #{params[:swlng].to_f} #{params[:nelat].to_f}, #{params[:swlng].to_f} #{params[:swlat].to_f}, #{params[:nelng].to_f} #{params[:swlat].to_f}, #{params[:nelng].to_f} #{params[:nelat].to_f}))'))"
    ifilter = "(import_id IS NULL OR import_id IN (#{Import.where("autoload #{mfilter}").collect{ |i| i.id }.join(",")}))"
    @locations = ActiveRecord::Base.connection.execute("SELECT l.id, l.lat, l.lng, l.unverified, l.description, l.season_start, l.season_stop, 
      l.no_season, l.author, l.address, l.created_at, l.updated_at, l.quality_rating, l.yield_rating, l.access, i.name as import_name, i.url as import_url, i.license as import_license,
      string_agg(coalesce(t.name,lt.type_other),',') as name from locations l, imports i,
      locations_types lt left outer join types t on lt.type_id=t.id 
      WHERE l.import_id=i.id AND lt.location_id=l.id AND 
      #{[bound,ifilter].compact.join(" AND ")} 
      GROUP BY l.id, l.lat, l.lng, l.unverified, l.description, l.season_start, l.season_stop, 
      l.no_season, l.address, l.created_at, l.updated_at, l.quality_rating, l.yield_rating, l.access, i.name, i.url, i.license 
      UNION
      SELECT l.id, l.lat, l.lng, l.unverified, l.description, l.season_start, l.season_stop, 
      l.no_season, l.author, l.address, l.created_at, l.updated_at, l.quality_rating, l.yield_rating, l.access, NULL as import_name, NULL as import_url, NULL as import_license,
      string_agg(coalesce(t.name,lt.type_other),',') as name from locations l, imports i,
      locations_types lt left outer join types t on lt.type_id=t.id 
      WHERE l.import_id IS NULL AND lt.location_id=l.id AND 
      #{[bound,ifilter].compact.join(" AND ")} 
      GROUP BY l.id, l.lat, l.lng, l.unverified, l.description, l.season_start, l.season_stop, 
      l.no_season, l.address, l.created_at, l.updated_at, l.quality_rating, l.yield_rating, l.access LIMIT #{max_n}")
    respond_to do |format|
      format.json { render json: @locations }
      format.csv { 
        csv_data = CSV.generate do |csv|
          cols = ["id","lat","lng","unverified","description","season_start","season_stop",
                  "no_season","author","address","created_at","updated_at",
                  "quality_rating","yield_rating","access","import_name","import_url","import_license","name"]
          csv << cols
          @locations.each{ |l|
            csv << cols.collect{ |e| l[e] }
          }
        end
        send_data(csv_data,:type => 'text/csv; charset=utf-8; header=present', :filename => 'data.csv')
      }
    end
  end

  def import
    if request.post? && params[:import][:csv].present?
      infile = params[:import][:csv].read
      n = 0
      errs = []
      text_errs = []
      ok_count = 0
      import = Import.new
      import.name = params[:import][:name]
      import.url = params[:import][:url]
      import.comments = params[:import][:comments]
      import.license = params[:import][:license]
      import.muni = params[:import][:muni].present? and params[:import][:muni].to_i == 1
      import.save
      CSV.parse(infile) do |row| 
        n += 1
        next if n == 1 or row.join.blank?
        location = Location.build_from_csv(row)
        location.import = import
        if params["import"]["geocode"].present? and params["import"]["geocode"].to_i == 1
          location.geocode
        end
        if location.valid?
          ok_count += 1
          location.save
          cluster_increment(location)
        else
          text_errs << location.errors
          errs << row
        end
      end
      log_changes(nil,"#{okay_count} new locations imported from #{import.name} (#{import.import_url})")
      if errs.any?
        if params["import"]["error_csv"].present? and params["import"]["error_csv"].to_i == 1
          errFile ="errors_#{Date.today.strftime('%d%b%y')}.csv"
          errs.insert(0,Location.csv_header)
          errCSV = CSV.generate do |csv|
            errs.each {|row| csv << row}
          end
          send_data errCSV,
            :type => 'text/csv; charset=iso-8859-1; header=present',
            :disposition => "attachment; filename=#{errFile}.csv"
        else
          flash[:notice] = "#{errs.length} rows generated errors, #{ok_count} worked"
          @errors = text_errs
        end
      else
        flash[:notice] = "Import total success"
      end
    end
  end

  def infobox
    @location = Location.find(params[:id])
    render(:partial => "/locations/infowindow", 
      :locals => {:location => @location}
    )
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
      lts = params[:location][:locations_types].collect{ |dc,data| 
        lt = LocationsType.new
        unless data[:type_id].nil? or (data[:type_id].strip == "")
          lt.type_id = data[:type_id]
        else
          lt.type_other = data[:type_other] unless data[:type_other].nil? or (data[:type_other].strip == "")
        end
        k = lt.type_id.nil? ? lt.type_other : lt.type_id
        if lt.type_id.nil? and lt.type_other.nil?
          lt = nil
        elsif !lt_seen[k].nil?
          lt = nil
        else
          lt_seen[k] = true
        end
        lt
      }.compact
      params[:location].delete(:locations_types)
    end
    @location = Location.new(params[:location])
    @lat = @location.lat
    @lng = @location.lng
    @location.locations_types += lts unless lts.nil?
    respond_to do |format|
      if (!current_admin.nil? or verify_recaptcha(:model => @location, :message => "ReCAPCHA error!")) and @location.save
        cluster_increment(@location)
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
    params[:location][:author] = @location.author unless admin_signed_in?

    # manually update location types :/
    unless params[:location].nil? or params[:location][:locations_types].nil?
      # delete existing types before adding new stuff
      @location.locations_types.collect{ |lt| LocationsType.delete(lt.id) }
      # add/update types
      lt_seen = {}
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
        lt.save
      }
      params[:location].delete(:locations_types)
    end

    cluster_decrement(@location)
    respond_to do |format|
      if (!current_admin.nil? or verify_recaptcha(:model => @location, :message => "ReCAPCHA error!")) and 
         @location.update_attributes(params[:location])
        log_changes(@location,"edited")
        cluster_increment(@location)
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
    cluster_decrement(@location)
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
end
