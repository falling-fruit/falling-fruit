class LocationsController < ApplicationController
  before_filter :authenticate_admin!, :only => [:destroy]
  before_filter :prepare_for_mobile, :except => [:cluster,:markers,:marker,:data,:infobox]

  def expire_things
    expire_fragment "pages_data_type_summary_table"
    expire_fragment "pages_about_stats"
  end

  def cluster
    mfilter = ""
    if params[:muni].present? and params[:muni].to_i == 1
      mfilter = "AND muni"
    elsif params[:muni].present? and params[:muni].to_i == 0
      mfilter = "AND NOT muni"
    end
    g = params[:grid].present? ? params[:grid].to_i : 1
    g = 12 if g > 12
    bound = [params[:nelat],params[:nelng],params[:swlat],params[:swlng]].any? { |e| e.nil? } ? "" : 
      "AND ST_INTERSECTS(polygon,ST_TRANSFORM(ST_SETSRID(ST_MakeBox2D(ST_POINT(#{params[:swlng]},#{params[:swlat]}),
                                                         ST_POINT(#{params[:nelng]},#{params[:nelat]})),4326),900913))"
    @clusters = Cluster.select("ST_X(ST_CENTROID(ST_COLLECT(cluster_point))) as center_x, 
                                ST_Y(ST_CENTROID(ST_COLLECT(cluster_point))) as center_y,
                                ST_X(ST_TRANSFORM(ST_CENTROID(ST_COLLECT(cluster_point)),4326)) as center_lng,
                                ST_Y(ST_TRANSFORM(ST_CENTROID(ST_COLLECT(cluster_point)),4326)) as center_lat,
                                grid_point, SUM(count) as count").group("grid_point").where("zoom = #{g} #{mfilter} #{bound}")
    @minmax = Cluster.select("MIN(count) as min_count, MAX(count) as max_count").where("zoom = #{g} #{mfilter}").shift
  
    # FIXME: calc pixel distances between, merge as necessary
    # calc percent using minmax
    @clusters.collect!{ |c|
      v = {}
      v[:lat] = c.center_lat
      v[:lng] = c.center_lng
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
      infile = params[:csv].read
      n = 0
      errs = []
      text_errs = []
      ok_count = 0
      import = Import.new(params[:import])
      import.save
      CSV.parse(infile) do |row| 
        n += 1
        next if n == 1 or row.join.blank?
        location = Location.build_from_csv(row)
        location.import = import
        location.client = 'import'
        if params["geocode"].present? and params["geocode"].to_i == 1
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
      log_changes(nil,"#{ok_count} new locations imported from #{import.name} (#{import.url})")
      if errs.any?
        if params["error_csv"].present? and params["error_csv"].to_i == 1
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
    respond_to do |format|
      format.html { render :partial => "/locations/infowindow", :locals => {:location => @location} }
      format.json { 
        @location["types"] = @location.locations_types
        render json: @location 
      }
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
