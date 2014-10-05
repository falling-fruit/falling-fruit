class LocationsController < ApplicationController
  before_filter :authenticate_user!, :only => [:destroy,:enroute,:home]
  authorize_resource :only => [:destroy,:enroute]

  def expire_things
    expire_fragment "pages_data_type_summary_table"
    expire_fragment "pages_about_stats"
  end

  def data
    max_n = 500
    cat_mask = array_to_mask(["human","freegan"],Type::Categories)
    mfilter = (params[:muni].present? and params[:muni].to_i == 1) ? nil : "NOT muni"
    bound = [params[:nelat],params[:nelng],params[:swlat],params[:swlng]].any? { |e| e.nil? } ? "" :
      "ST_INTERSECTS(location,ST_SETSRID(ST_MakeBox2D(ST_POINT(#{params[:swlng]},#{params[:swlat]}),
                                                     ST_POINT(#{params[:nelng]},#{params[:nelat]})),4326))"
    i18n_name_field = I18n.locale != :en ? "types.#{I18n.locale.to_s.tr("-","_")}_name," : ""
    @locations = Location.joins("INNER JOIN types ON t.id=ANY(locations.type_ids)").
             joins("LEFT OUTER JOIN imports ON locations.import_id=imports.id").
             select("ARRAY_AGG(COALESCE(#{i18n_name_field}types.name)) as name, type_others, locations.id as id,
                     description, lat, lng, address, season_start, season_stop, no_season, access, unverified, 
                     author, import_id, locations.created_at, locations.updated_at, muni").
             where([bound,mfilter,"(types.category_mask & #{cat_mask})>0"].compact.join(" AND ")).
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
            				l.season_start.nil? ? nil : I18n.t("date.month_names")[l.season_start+1],
                    l.season_stop.nil? ? nil : I18n.t("date.month_names")[l.season_stop+1],
                    l.no_season,
                    quality_rating.nil? ? nil : I18n.t("locations.infowindow.rating")[quality_rating],
                    yield_rating.nil? ? nil : I18n.t("locations.infowindow.rating")[yield_rating],
                    l.author,l.address,l.created_at,l.updated_at,
                    l.access.nil? ? nil : I18n.t("locations.infowindow.access_short")[l.access],
                    l.import_id.nil? ? nil : "http://fallingfruit.org/imports/#{l.import_id}",
                    l.import_id.nil? ? false : (l.muni ? true : false), 
                    l.title]
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
    end
  end

  def embed
    prepare_from_permalink
    @type = params[:f].present? ? Type.find(params[:f]) : nil
    @width = params[:width].present? ? params[:width].to_i : 640
    @height = params[:height].present? ? params[:height].to_i : 600
    respond_to do |format|
      format.html { render :layout => false } # embed.html.erb
    end
  end

  # GET /dumpsters
  # GET /freegan
  def freegan_index
    @freegan = true
    @type = Type.find_by_name('Freegan')
    params[:f] = @type.id
    params[:t] = 'toner-lite'
    params[:c] = 'human,freegan'
    params[:m] = 'false'
    index and return
  end

  # GET /locations/home
  def home
    prepare_for_sidebar if user_signed_in?
    index
  end

  # GET /locations
  # GET /locations.json
  def index
    prepare_from_permalink
    respond_to do |format|
      format.html { render "index" }# index.html.erb
      format.json { render json: @locations }
      format.csv { render :csv => @locations }
    end
  end

  def show
    @location = Location.find(params[:id])
    prepare_from_permalink
    respond_to do |format|
      format.html
      format.mobile
    end
  end

  # GET /locations/new
  # GET /locations/new.json
  def new
    @location = Location.new
    @location.type_ids = []
    @location.type_others = []
    @lat = nil
    @lng = nil
    unless params[:lat].nil? or params[:lng].nil?
      @lat = params[:lat].to_f
      @lng = params[:lng].to_f
      @location.lat = @lat
      @location.lng = @lng
    end
    @cats = params[:c].split(/,/) if params[:c].present?
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
    @location = Location.new(params[:location])
    params[:types].split(/,/).collect{ |e| e[/^([^\[]*)/].strip.capitalize }.uniq.each{ |type_name|
      t = Type.where("name = ?",type_name.strip).first
      if t.nil? 
        @location.type_others.push type_name
      else
        @location.type_ids.push t.id
      end
    } if params[:types].present?
    @location.user = current_user if user_signed_in?

    # create an observation if necessary
    @obs = nil
    if [:quality_rating,:yield_rating,:fruiting,:photo,:comment].collect{ |k| params[k].present? }.any?
      @obs = Observation.new
      @obs.quality_rating = params[:quality_rating].to_i unless params[:quality_rating].blank?
      @obs.yield_rating = params[:yield_rating].to_i unless params[:yield_rating].blank?
      @obs.fruiting = params[:fruiting].to_i unless params[:fruiting].blank?
      @obs.comment = params[:comment] unless params[:comment].blank?
      unless params[:photo].blank?
      	@obs.photo_caption = params[:photo_caption].to_i unless params[:photo_caption].blank?
      end
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

    # compute diff/patch so we can undo later
    dmp = DiffMatchPatch.new
    patch = dmp.patch_to_text(dmp.patch_make(params[:location][:description],@location.description))
    former_type_ids = @location.type_ids
    former_type_others = @location.type_others
    former_location = @location.location

    p = 0
    lts = []
    @location.type_ids = []
    @location.type_others = []
    params[:types].split(/,/).collect{ |e| e[/^([^\[]*)/].strip.capitalize }.uniq.each{ |type_name|
      t = Type.where("name = ?",type_name).first
      if t.nil? 
        @location.type_others.push type_name
      else
        @location.type_ids.push t.id
      end
    } if params[:types].present?
    lt_update_okay = @location.save

    ApplicationController.cluster_decrement(@location)
    respond_to do |format|
      test = user_signed_in? ? true : verify_recaptcha(:model => @location, 
                                                       :message => "ReCAPCHA error!")
      if test and @location.update_attributes(params[:location]) and lt_update_okay
        log_changes(@location,"edited",nil,params[:author],patch,former_type_ids,former_type_others,former_location)
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
    expire_things
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
      @route.transport_type = Route::TransportTypes.index("Walking")
      @route.save
      lr = LocationsRoute.new
      lr.route = @route
      lr.location = @location
      lr.position = 0
      lr.save
    else
      @route = Route.find(params[:route_id])
      lr = LocationsRoute.where("route_id = ? AND location_id = ?",@route.id,@location.id)
      if lr.nil? or lr.length == 0
        lr = LocationsRoute.new
        lr.route = @route
        lr.location_id = @location.id
        max = LocationsRoute.select("MAX(position) as max").where("route_id = ?",@route.id).first.max
        lr.position = max.nil? ? 0 : max.to_i+1
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
    i18n_name_field = I18n.locale != :en ? "t.#{I18n.locale.to_s.tr("-","_")}_name," : ""
    rangeq = current_user.range.nil? ? "" : "AND ST_INTERSECTS(l.location,(SELECT range FROM users u2 WHERE u2.id=#{current_user.id}))"
    r = ActiveRecord::Base.connection.execute("SELECT string_agg(COALESCE(#{i18n_name_field}t.name),' - ') as type_title, array_to_string(type_others,' - ') as type_others,
      extract(days from (NOW()-c.created_at)) as days_ago, c.location_id, c.user_id, c.description, c.remote_ip, l.city, l.state,
      l.country, l.lat, l.lng, l.description as location_description, c.author as change_author, l.id
      FROM changes c, locations l, types t
      WHERE t.id=ANY(l.type_ids) AND l.id=c.location_id #{rangeq}
      GROUP BY l.id, c.location_id, c.user_id, c.description, c.remote_ip, c.created_at, c.author ORDER BY c.created_at DESC LIMIT 100");
    @changes = r.collect{ |row| row }
    @mine = Observation.joins(:location).select('max(observations.created_at) as created_at,observations.user_id,location_id,lat,lng').
      where("observations.user_id = ?",current_user.id).group("location_id,observations.user_id,lat,lng,observations.created_at").
      order('observations.created_at desc')
    @mine.uniq!{ |o| o.location_id }
    @routes = Route.where("user_id = ?",current_user.id)
    @zoom_to_polygon = current_user.range
    @show_sidebar = true
  end

  def prepare_from_permalink
    @perma = {}
    @perma[:zoom] = params[:z].to_i if params[:z].present?
    @perma[:lat] = params[:y].to_f if params[:y].present?
    @perma[:lng] = params[:x].to_f if params[:x].present?
    @perma[:muni] = params[:m] == "true" if params[:m].present?
    @perma[:labels] = params[:l] == "true" if params[:l].present?
    @perma[:type] = params[:t] if params[:t].present?
    @perma[:cats] = params[:c] if params[:c].present?
    @perma[:center_mark] = params[:center_mark] == "true" if params[:center_mark].present?
    @perma[:center_radius] = params[:circle].to_i if params[:circle].present?
    unless @freegan
      @type = params[:f].present? ? Type.find(params[:f]) : nil
    end
  end

end
