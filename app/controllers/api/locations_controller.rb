class Api::LocationsController < ApplicationController
  respond_to :json
  before_filter :authenticate_user!, :only => [:mine,:favorite,:update]

  # API endpoint to give access to types list
  def types
    if !@api_key.nil? and @api_key.api_type == "muni"
      params[:c] = "forager"
    end

    if params[:c].blank?
      cat_mask = array_to_mask(["forager","freegan"],Type::Categories)
    else
      cat_mask = array_to_mask(params[:c].split(/,/),Type::Categories)
    end

    cfilter = "(category_mask & #{cat_mask})>0 AND NOT pending"

    @types = Type
      .where(cfilter)
      .collect { |t| { :name => t.full_name, :id => t.id } }
      .sort{ |x, y| x[:name] <=> y[:name] }

    log_api_request("api/locations/types", @types.length)

    respond_to do |format|
      format.json { render json: @types }
    end
  end

  def mine
    return unless check_api_key!("api/locations/mine")
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
    return unless check_api_key!("api/locations/show")
    @location = Location.find(params[:id])

    @location[:title] = @location.title
    @location[:photos] = @location.observations.collect{ |o|
      o.photo_file_name.nil? ? nil : { :updated_at => o.photo_updated_at, :url => o.photo.url }
    }.compact unless @api_key.api_type == "muni"
    @location[:num_reviews] = @location.observations.length
    if @api_key.api_type == "muni" and not @location.import.nil?
      @location[:source] = {:license => @location.import.license,
                            :name => @location.import.name,
      }
    end
    log_api_request("api/locations/show",1)
    respond_to do |format|
      format.json { render json: @location }
    end
  end

  def reviews
    return unless check_api_key!("api/locations/reviews")
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

  # PUT /api/locations/1.json
  def add_review
    return unless check_api_key!("api/locations/update")
    @location = Location.find(params[:id])

    obs_params = params[:observation]
    @observation = nil
    unless obs_params.nil? or obs_params.values.all?{|x| x.blank? }
      # deal with photo data in expected JSON format
      # (as opposed to something already caught and parsed by paperclip)
      unless obs_params["photo_data"].nil?
        tempfile = Tempfile.new("fileupload")
        tempfile.binmode
        data = obs_params["photo_data"]["data"].include?(",") ? obs_params["photo_data"]["data"].split(/,/)[1] : obs_params["photo_data"]["data"]
        tempfile.write(Base64.decode64(data))
        tempfile.rewind
        uploaded_file = ActionDispatch::Http::UploadedFile.new(
          :tempfile => tempfile,
          :type => "image/jpeg",
          :filename => "upload.jpg"
        )
        obs_params[:photo] = uploaded_file
        obs_params.delete(:photo_data)
      end
      @observation = Observation.new(obs_params)
      @observation.location = @location
      @observation.author = current_user.name unless (not user_signed_in?) or (current_user.add_anonymously)
      @observation.observed_on = Date.today if @observation.observed_on.nil?
    end
    log_api_request("api/locations/add_review",1)
    respond_to do |format|
      if @observation.save
        format.json { render json: {"status" => 0} }
      else
        format.json { render json: {"status" => 2, "error" => "Failed to update" } }
      end
    end
  end

  def nearby
    return unless check_api_key!("api/locations/nearby")
    # Muni API is locked to muni & forager
    if !@api_key.nil? and @api_key.api_type == "muni"
      params[:muni] = 1
      params[:c] = "forager"
    end
    max_n = 100
    offset_n = params[:offset].present? ? params[:offset].to_i : 0
    if params[:c].blank?
      cat_mask = array_to_mask(["forager","freegan"],Type::Categories)
    else
      cat_mask = array_to_mask(params[:c].split(/,/),Type::Categories)
    end
    bound = [params[:nelat],params[:nelng],params[:swlat],params[:swlng]].any? { |e| e.nil? } ? nil :
      "ST_INTERSECTS(location,ST_SETSRID(ST_MakeBox2D(ST_POINT(#{params[:swlng]},#{params[:swlat]}),
                                                     ST_POINT(#{params[:nelng]},#{params[:nelat]})),4326))"
    cfilter = "(bit_or(t.category_mask) & #{cat_mask})>0"
    mfilter = (params[:muni].present? and params[:muni].to_i == 1) ? nil : "NOT muni"
    hfilter = "NOT hidden"
    sorted = "1 as sort"
    # FIXME: would be easy to allow t to be an array of typesq
    if params[:t].present?
      type = Type.find(params[:t])
      tids = ([type.id] + type.all_children.collect{ |c| c.id }).compact.uniq
      sorted = "CASE WHEN array_agg(t.id) @> ARRAY[#{tids.join(",")}] THEN 0 ELSE 1 END as sort"
    end
    unless params[:lat].present? and params[:lng].present?
      # error!
      return
    end
    dist = "ST_Distance(l.location,ST_SETSRID(ST_POINT(#{params[:lng]},#{params[:lat]}),4326))"
    dfilter = "ST_DWithin(l.location,ST_SETSRID(ST_POINT(#{params[:lng]},#{params[:lat]}),4326),100000)" # must be within 100k!
    i18n_name_field = "t.#{I18n.locale.to_s.tr("-","_")}_name"
    r = ActiveRecord::Base.connection.execute("SELECT l.id, l.lat, l.lng, l.unverified, l.type_ids as types, count(o.*),
      #{dist} as distance, l.description, l.author,
      array_agg(t.parent_id) as parent_types,
      string_agg(coalesce(#{i18n_name_field}, t.en_name),',') AS name,
      #{sorted} FROM locations l LEFT JOIN observations o ON o.location_id=l.id, types t
      WHERE #{[bound,dfilter,mfilter,hfilter].compact.join(" AND ")} AND t.id=ANY(l.type_ids)
      GROUP BY l.id, l.lat, l.lng, l.unverified HAVING #{[cfilter].compact.join(" AND ")} ORDER BY distance ASC, sort
      LIMIT #{max_n} OFFSET #{offset_n}");
    @markers = r.collect{ |row|
      row["parent_types"] = row["parent_types"].tr('{}','').split(/,/).reject{ |x| x == "NULL" }.collect{ |e| e.to_i }
      row["types"] = row["types"].tr('{}','').split(/,/).reject{ |x| x == "NULL" }.collect{ |e| e.to_i }
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
      {:title => name, :location_id => row["id"].to_i,
       :lat => row["lat"].to_f, :lng => row["lng"].to_f,
       :distance => row["distance"].to_f.round,
       :description => row["description"], :author => row["author"],
       :num_reviews => row["count"].to_i
      }
    } unless r.nil?
    photo_having_lids = @markers.collect{ |m| m[:num_reviews] > 0 ? m[:location_id] : nil }.compact
    obs_hash = {}
    Observation.where("location_id IN (#{photo_having_lids.join(",")})").collect{ |o|
      obs_hash[o.location_id] = [] if obs_hash[o.location_id].nil?
      obs_hash[o.location_id] << [:thumbnail => o.photo(:thumb), :created_at => o.created_at]
    } unless photo_having_lids.empty?
    @markers.collect{ |m|
      m[:photos] = obs_hash[m[:location_id]] unless obs_hash[m[:location_id]].nil?
    }
    log_api_request("api/locations/nearby",@markers.length)
    respond_to do |format|
      format.json { render json: @markers }
    end
  end

  # Currently keeps max_n markers, and displays filtered out markers as translucent grey.
  # Unverified no longer has its own color.
  def markers
    return unless check_api_key!("api/locations/markers")
    if params[:n].present?
      max_n = [1000,params[:n].to_i].min
    else
      max_n = 1000
    end
    # Muni API is locked to muni & forager
    if !@api_key.nil? and @api_key.api_type == "muni"
      params[:muni] = 1
      params[:c] = "forager"
      max_n = [100,max_n].min
    end
    offset_n = params[:offset].present? ? params[:offset].to_i : 0

    if params[:c].blank?
      cat_mask = array_to_mask(["forager","freegan"],Type::Categories)
    else
      cat_mask = array_to_mask(params[:c].split(/,/),Type::Categories)
    end
    cfilter = "(bit_or(t.category_mask) & #{cat_mask})>0"
    mfilter = (params[:muni].present? and params[:muni].to_i == 1) ? "" : "AND NOT muni"
    hfilter = "AND NOT hidden"
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
    r = ActiveRecord::Base.connection.select_one("SELECT COUNT(*)
      FROM locations l, types t
      WHERE t.id=ANY(l.type_ids) AND #{bound} #{mfilter} #{hfilter}")
    found_n = r["count"].to_i unless r.nil?
    i18n_name_field = "t.#{I18n.locale.to_s.tr("-","_")}_name"
    r = ActiveRecord::Base.connection.execute("SELECT l.id, l.lat, l.lng, l.unverified, l.type_ids as types,
      array_agg(t.parent_id) as parent_types, string_agg(coalesce(#{i18n_name_field}, t.en_name),',') AS name, #{sorted}
      FROM locations l, types t
      WHERE t.id=ANY(l.type_ids) AND #{bound} #{mfilter} #{hfilter}
      GROUP BY l.id, l.lat, l.lng, l.unverified HAVING #{[cfilter].compact.join(" AND ")} ORDER BY sort LIMIT #{max_n} OFFSET #{offset_n}");
    @markers = r.collect{ |row|
      row["parent_types"] = row["parent_types"].tr('{}','').split(/,/).reject{ |x| x == "NULL" }.collect{ |e| e.to_i }
      row["types"] = row["types"].tr('{}','').split(/,/).reject{ |x| x == "NULL" }.collect{ |e| e.to_i }
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
       :types => row["types"],:parent_types => row["parent_types"]
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
    return unless check_api_key!("api/locations/marker")
     id = params[:id].to_i
     i18n_name_field = "t.#{I18n.locale.to_s.tr("-","_")}_name"
     r = ActiveRecord::Base.connection.execute("SELECT l.id, l.lat, l.lng, l.unverified, array_agg(t.id) as types,
      array_agg(t.parent_id) as parent_types,
      string_agg(coalesce(#{i18n_name_field}, t.en_name),',') as name
      FROM locations l, types t
      WHERE t.id=ANY(l.type_ids) AND l.id=#{id}
      GROUP BY l.id, l.lat, l.lng, l.unverified")
    @markers = r.collect{ |row|
      row["parent_types"] = row["parent_types"].tr('{}','').split(/,/).reject{ |x| x == "NULL" }.collect{ |e| e.to_i }
      row["types"] = row["types"].tr('{}','').split(/,/).reject{ |x| x == "NULL" }.collect{ |e| e.to_i }
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
       :parent_types => row["parent_types"],:n => 1, :types => row["types"]}
    } unless r.nil?
    log_api_request("api/locations/marker",1)
    respond_to do |format|
      format.json { render json: @markers }
    end
  end

end
