var db = require('./db');
var async = require("async");
var __ = require("underscore");
var express = require('express');
var apicache = require('apicache').options({ debug: true }).middleware;
var app = express();

// Helper functions
function catmask(cats) {
  var options = ["forager","freegan","honeybee","grafter"];
  return __.reduce(__.pairs(options),function(memo,pair){
    return memo | (__.contains(cats,pair[1]) ? 1<<parseInt(pair[0]) : 0)
  },0);
}
var default_catmask = catmask(["forager","freegan"]);

function i18n_name(locale) {
  if(__.contains(["es","he","pt","it","fr","de","pl"],locale)) return locale + "_name";
  else return "name";
}

function postgis_bbox(v,nelat,nelng,swlat,swlng,srid){
  if(swlng < nelng){
    if(srid == 900913){
      return "AND ST_INTERSECTS("+v+",ST_TRANSFORM(ST_SETSRID(ST_MakeBox2D(ST_POINT("+
             swlng+","+swlat+"), ST_POINT("+nelng+","+nelat+")),4326),900913))";
    }else{ // assume 4326
      return "AND ST_INTERSECTS("+v+",ST_SETSRID(ST_MakeBox2D(ST_POINT("+
             swlng+","+swlat+"), ST_POINT("+nelng+","+nelat+")),4326))";
    }
  }else{
    if(srid == 900913){
      return "AND (ST_INTERSECTS("+v+",ST_TRANSFORM(ST_SETSRID(ST_MakeBox2D(ST_POINT(-180,"+
             swlat+"), ST_POINT("+nelng+","+nelat+")),4326),900913)) OR \
             ST_INTERSECTS("+v+",ST_TRANSFORM(ST_SETSRID(ST_MakeBox2D(ST_POINT("+
             swlng+","+swlat+"), ST_POINT(180,"+nelat+")),4326),900913)))";
    }else{ // assume 4326
      return "AND (ST_INTERSECTS("+v+",ST_SETSRID(ST_MakeBox2D(ST_POINT(-180,"+
             swlat+"), ST_POINT("+nelng+","+nelat+")),4326)) OR \
             ST_INTERSECTS("+v+",ST_SETSRID(ST_MakeBox2D(ST_POINT("+
             swlng+","+swlat+"), ST_POINT(180,"+nelat+")),4326)))";
    }
  }
}

function send_error(res,msg,logmsg){
  res.send({"error": msg});
  console.error("ERROR: ",msg,logmsg);
}

// Waterfall Helper functions

function check_api_key(req,client,callback){
  if(!req.query.api_key) return callback(true,'api key missing');
  client.query("SELECT 1 FROM api_keys WHERE api_key=$1;",
               [req.query.api_key],function(err, result) {
    if (err) callback(err,'error running query');
    if(result.rowCount == 0){
      callback(true,'api key is invalid');
    }else{
      callback(null);
    }
  });
}


// Routes

// Note: grid parameter replaced by zoom
// Note: now can accept a bounding box, obviating the cluster_types.json endpoint
app.get('/types.json', apicache('1 hour'), function (req, res) {
  var cmask = default_catmask;
  if(req.query.c) cmask = catmask(req.query.c.split(",")); 
  var name = "name";
  if(req.query.locale) name = i18n_name(req.query.locale); 
  var mfilter = "";
  if(req.query.muni == 0) mfilter = "AND NOT muni";
  var bfilter = undefined;
  var zfilter = "AND zoom=2";
  if(__.every([req.query.swlat,req.query.swlng,req.query.nelat,req.query.nelng])){
    bfilter = postgis_bbox("cluster_point",parseFloat(req.query.nelat),parseFloat(req.query.nelng),
                           parseFloat(req.query.swlat),parseFloat(req.query.swlng),900913);
    if(req.query.zoom) zfilter = "AND zoom="+parseInt(req.query.zoom);
  }
  db.pg.connect(db.conString, function(err, client, done) {
    if (err){ 
      send_error(res,'error fetching client from pool',err);
      return done();
    }
    async.waterfall([
      function(callback){ check_api_key(req,client,callback) },
      function(callback){
        if(bfilter){
          filters = __.reject([bfilter,mfilter,zfilter],__.isUndefined).join(" ");
          client.query("SELECT t.id, COALESCE("+name+",name) as name,scientific_name,SUM(count) as count \
                        FROM types t, clusters c WHERE c.type_id=t.id AND NOT pending \
                        AND (category_mask & $1)>0 "+filters+" GROUP BY t.id, name, scientific_name \
                        ORDER BY name,scientific_name;",
                       [cmask],function(err, result) {
            if (err) callback(err,'error running query');
            res.send(__.map(result.rows,function(x){ 
              x.count = parseInt(x.count); 
              return x; 
            }));
          });
        }else{
          client.query("SELECT id, COALESCE("+name+",name) as name,scientific_name FROM types WHERE NOT \
                        pending AND (category_mask & $1)>0 ORDER BY name,scientific_name;",
                       [cmask],function(err, result) {
            if (err) callback(err,'error running query');
            res.send(result.rows);
          });
        }
      }
    ],
    function(err,message){
      done();
      if(message) send_error(res,message,err);
    }); 
  });
});

// Note: types renamed to type_ids
// Note: n renamed to limit
// Note: name (string) replaced with type_names (array)
// Note: title removed (client can create from type_names)
// FIXME: does not include child types, leaves it to the client to do that with t argument
// Note: can take lat/lng to obviate need for nearby.json
// Note: returns only the most recent photo, not an array of photos
// FIXME: convert photo_file_name to URL (thumbnail)
app.get('/locations.json', function (req, res) {
  var cmask = default_catmask;
  if(req.query.c) cmask = catmask(req.query.c.split(",")); 
  var cfilter = "(bit_or(t.category_mask) & "+cmask+")>0";
  var name = "name";
  if(req.query.locale) name = i18n_name(req.query.locale); 
  var mfilter = "";
  if(req.query.muni == 0) mfilter = "AND NOT muni";
  var bfilter = undefined;
  if(__.every([req.query.swlat,req.query.swlng,req.query.nelat,req.query.nelng])){
    bfilter = postgis_bbox("location",parseFloat(req.query.nelat),parseFloat(req.query.nelng),
                           parseFloat(req.query.swlat),parseFloat(req.query.swlng));
  }else{
    return send_error(res,'bounding box not defined');    
  }
  var sorted = "1 as sort";
  if(req.query.t){
    var tids = __.map(req.query.t.split(","),function(x){ parseInt(x) });
    sorted = "CASE WHEN array_agg(t.id) @> ARRAY["+tids+"] THEN 0 ELSE 1 END as sort";
  }
  var limit = req.query.limit ? __.min([parseInt(req.query.limit),1000]) : 1000;
  var offset = req.query.offset ?parseInt(req.query.offset) : 0;
  var filters = __.reject([bfilter,mfilter],__.isUndefined).join(" ");
  var distance = "";
  if(__.every([req.query.lat,req.query.lng])){
    distance = ",ST_Distance(l.location,ST_SETSRID(ST_POINT("+parseFloat(req.query.lng)+
               ","+parseFloat(req.query.lat)+"),4326)) as distance";
  }
  var reviews = "";
  if(req.query.reviews == 1){
    reviews = ",(SELECT COUNT(*) FROM observations o1 WHERE o1.location_id=l.id) AS num_reviews,\
               (SELECT photo_file_name FROM observations o2 WHERE o2.location_id=l.id AND \
                photo_file_name IS NOT NULL \
                ORDER BY photo_file_name DESC LIMIT 1) as photo_file_name";
  }
  db.pg.connect(db.conString, function(err, client, done) {
    if (err){ 
      send_error(res,'error fetching client from pool',err);
      return done();
    }
    async.waterfall([
      function(callback){ check_api_key(req,client,callback) },
      function(callback){
        client.query("SELECT COUNT(*) FROM locations l, types t WHERE t.id=ANY(l.type_ids) "+
                      filters+";",[],function(err,result){
          if (err) callback(err,'error running query');
          else callback(null,parseInt(result.rows[0].count));
        });
      },
      function(total_count,callback){
        client.query("SELECT l.id, l.lat, l.lng, l.unverified, l.type_ids, \
                      l.description, l.author, \
                      ARRAY_AGG(COALESCE("+name+",name)) AS type_names, \
                      "+sorted+distance+reviews+" FROM locations l, types t\
                      WHERE t.id=ANY(l.type_ids) "+filters+" GROUP BY l.id, l.lat, l.lng, l.unverified \
                      HAVING "+cfilter+" ORDER BY sort LIMIT $1 OFFSET $2;",
                     [limit,offset],function(err, result) {
          if (err) callback(err,'error running query');
          res.send([result.rowCount,total_count].concat(result.rows));
        });
      }
    ],
    function(err,message){
      done();
      if(message) send_error(res,message,err);
    }); 
  });
});

// NOTE: title has been replaced with type_names
// FIXME: convert photo_file_name to photo_url
app.get('/locations/:id(\\d+).json', function (req, res) {
  var id = req.params.id;
  var name = "name";
  if(req.query.locale) name = i18n_name(req.query.locale); 
  db.pg.connect(db.conString, function(err, client, done) {
    if (err){ 
      send_error(res,'error fetching client from pool',err);
      return done();
    }
    async.waterfall([
      function(callback){ check_api_key(req,client,callback) },
      function(callback){
        client.query("SELECT access, address, author, city, state, country, description, \
                      id, lat, lng, muni, type_ids, unverified, \
                      (SELECT ARRAY_AGG(COALESCE("+name+",name)) FROM types t \
                       WHERE ARRAY[t.id] <@ l.type_ids) as type_names, \
                      (SELECT COUNT(*) FROM observations o WHERE o.location_id=l.id) as num_reviews \
                      FROM locations l WHERE id=$1;",
                     [id],function(err, result) {
          if (err) callback(err,'error running query');
          if (result.rowCount == 0) return res.send({});
          location = result.rows[0];
          location.num_reviews = parseInt(location.num_reviews);
          client.query("SELECT photo_updated_at, photo_file_name FROM observations \
                        WHERE photo_file_name IS NOT NULL AND location_id=$1;",
                       [id],function(err, result) {
            if (err) callback(err,'error running query');
            location.photos = result.rows;
            res.send(location);
          });
        });
      }
    ],
    function(err,message){
      done();
      if(message) send_error(res,message,err);
    }); 

  });
});

// FIXME: convert photo_file_name to photo_url
app.get('/locations/:id(\\d+)/reviews.json', function (req, res) {
  var id = req.params.id;
  db.pg.connect(db.conString, function(err, client, done) {
    if (err){ 
      send_error(res,'error fetching client from pool',err);
      return done();
    }
    async.waterfall([
      function(callback){ check_api_key(req,client,callback) },
      function(callback){
        client.query("SELECT id, location_id, comment, observed_on, \
                      photo_file_name, fruiting, quality_rating, yield_rating, author, photo_caption \
                      FROM observations WHERE location_id=$1;",
                     [id],function(err, result) {
          if (err) callback(err,'error running query');
          res.send(result.rows);
        });
      }
    ],
    function(err,message){
      done();
      if(message) send_error(res,message,err);
    });    
  });
});

// TODO:

//  def mine
//    return unless check_api_key!("api/locations/mine")
//    @mine = Observation.joins(:location).select('max(observations.created_at) as created_at,observations.user_id,location_id,lat,lng').
//      where("observations.user_id = ?",current_user.id).group("location_id,observations.user_id,lat,lng,observations.created_at").
//      order('observations.created_at desc')
//    @mine.uniq!{ |o| o.location_id }
//    @mine.each_index{ |i|
//      loc = @mine[i].location
//      @mine[i] = loc.attributes
//      @mine[i]["title"] = loc.title
//      @mine[i].delete("user_id")
//    }
//    log_api_request("api/locations/mine",@mine.length)
//    respond_to do |format|
//      format.json { render json: @mine }
//    end
//  end

//  
//  # PUT /api/locations/1.json
//  def add_review
//    return unless check_api_key!("api/locations/update")
//    @location = Location.find(params[:id])
//    
//    obs_params = params[:observation]
//    @observation = nil
//    unless obs_params.nil? or obs_params.values.all?{|x| x.blank? }
//      # deal with photo data in expected JSON format
//      # (as opposed to something already caught and parsed by paperclip)
//      unless obs_params["photo_data"].nil?
//        tempfile = Tempfile.new("fileupload")
//        tempfile.binmode
//        data = obs_params["photo_data"]["data"].include?(",") ? obs_params["photo_data"]["data"].split(/,/)[1] : obs_params["photo_data"]["data"]
//        tempfile.write(Base64.decode64(data))
//        tempfile.rewind
//        uploaded_file = ActionDispatch::Http::UploadedFile.new(
//          :tempfile => tempfile,
//          :filename => obs_params["photo_data"]["name"],
//          :type => obs_params["photo_data"]["type"]
//        )
//        obs_params[:photo] = uploaded_file
//        obs_params.delete(:photo_data)
//      end
//      @observation = Observation.new(obs_params)
//      @observation.location = @location
//      @observation.author = current_user.name unless (not user_signed_in?) or (current_user.add_anonymously)
//    end
//    log_api_request("api/locations/add_review",1)
//    respond_to do |format|
//      if @observation.save
//        format.json { render json: {"status" => 0} }
//      else
//        format.json { render json: {"status" => 2, "error" => "Failed to update" } }
//      end
//    end
//  end
//  

//  def cluster
//    return unless check_api_key!("api/locations/cluster")
//    # Muni API is locked to muni & forager
//    if !@api_key.nil? and @api_key.api_type == "muni"
//      params[:muni] = 1
//      params[:c] = "forager"
//    end
//    mfilter = ""
//    if params[:muni].present? and params[:muni].to_i == 1
//      mfilter = ""
//    elsif params[:muni].present? and params[:muni].to_i == 0
//      mfilter = "AND NOT muni"
//    end
//    tfilter = "AND type_id IS NULL"
//    if params[:t].present?
//      type = Type.find(params[:t])
//      tids = ([type.id] + type.all_children.collect{ |c| c.id }).compact.uniq
//      tfilter = "AND type_id IN (#{tids.join(",")})"
//    end
//    g = params[:grid].present? ? params[:grid].to_i : 2
//    g = 12 if g > 12
//    if [params[:nelat],params[:nelng],params[:swlat],params[:swlng]].any? { |e| e.nil? }
//      bound = ""
//    elsif params[:swlng].to_f < params[:nelng].to_f
//      bound = "AND ST_INTERSECTS(polygon,ST_TRANSFORM(ST_SETSRID(ST_MakeBox2D(ST_POINT(#{params[:swlng]},#{params[:swlat]}), ST_POINT(#{params[:nelng]},#{params[:nelat]})),4326),900913))"
//    else # map spans -180 | 180 seam, split into two polygons
//      bound = "AND (ST_INTERSECTS(polygon,ST_TRANSFORM(ST_SETSRID(ST_MakeBox2D(ST_POINT(-180,#{params[:swlat]}), ST_POINT(#{params[:nelng]},#{params[:nelat]})),4326),900913)) OR ST_INTERSECTS(cluster_point,ST_TRANSFORM(ST_SETSRID(ST_MakeBox2D(ST_POINT(#{params[:swlng]},#{params[:swlat]}), ST_POINT(180,#{params[:nelat]})),4326),900913)))"
//    end
//    
//    @clusters = Cluster.select("SUM(count*ST_X(cluster_point))/SUM(count) as center_x,
//                                SUM(count*ST_Y(cluster_point))/SUM(count) as center_y,
//                                SUM(count) as count").group("grid_point").where("zoom = #{g} #{mfilter} #{tfilter} #{bound}")
//                                
//    earth_radius = 6378137.0
//    earth_circum = 2.0*Math::PI*earth_radius
//    
//    # Conversion SRID 4326 <-> 900913
//    # x = (lng/360)*earth_circum
//    # lng = x*(360/earth_circum)
//    # y = Math.log(Math.tan((lat+90)*(Math::PI/360)))*earth_radius
//    # lat = 90-(Math.atan2(1,Math.exp(y/earth_radius))*(360/Math::PI))
//    
//    # FIXME: calc pixel distances between cluster positions, merge as necessary
//    @clusters.collect!{ |c|
//      v = {}
//      
//      # make single cluster at z = 0 snap to middle of map (optional)
//      if g == 0
//        v[:lat] = 0
//        v[:lng] = 0
//      else      
//        v[:lat] = 90-(Math.atan2(1,Math.exp(c.center_y.to_f/earth_radius))*(360/Math::PI))
//        v[:lng] = c.center_x.to_f*(360/earth_circum)
//      end
//      v[:n] = c.count
//      v[:title] = number_to_human(c.count)
//      v
//    }
//    log_api_request("api/locations/cluster",@clusters.length)
//    respond_to do |format|
//      format.json { render json: @clusters }
//    end
//  end


//  def marker
//    return unless check_api_key!("api/locations/marker")
//     id = params[:id].to_i
//     i18n_name_field = I18n.locale != :en ? "t.#{I18n.locale.to_s.tr("-","_")}_name," : ""
//     r = ActiveRecord::Base.connection.execute("SELECT l.id, l.lat, l.lng, l.unverified, array_agg(t.id) as types,
//      array_agg(t.parent_id) as parent_types,
//      string_agg(coalesce(#{i18n_name_field}t.name),',') as name    
//      FROM locations l, types t
//      WHERE t.id=ANY(l.type_ids) AND l.id=#{id}
//      GROUP BY l.id, l.lat, l.lng, l.unverified")
//    @markers = r.collect{ |row|
//      row["parent_types"] = row["parent_types"].tr('{}','').split(/,/).reject{ |x| x == "NULL" }.collect{ |e| e.to_i }
//      row["types"] = row["types"].tr('{}','').split(/,/).reject{ |x| x == "NULL" }.collect{ |e| e.to_i }
//      if row["name"].nil? or row["name"].strip == ""
//        name = "Unknown"
//      else
//        t = row["name"].split(/,/)
//        if t.length == 2
//          name = "#{t[0]} & #{t[1]}"
//        elsif t.length > 2
//          name = "#{t[0]} & Others"
//        else
//          name = t[0]
//        end
//      end
//      {:title => name, :location_id => row["id"], :lat => row["lat"], :lng => row["lng"], 
//       :parent_types => row["parent_types"],:n => 1, :types => row["types"]}
//    } unless r.nil?
//    log_api_request("api/locations/marker",1)
//    respond_to do |format|
//      format.json { render json: @markers }
//    end
//  end

//end

var server = app.listen(3100, function () {

  var host = server.address().address;
  var port = server.address().port;

  console.log('Falling Fruit API listening at http://%s:%s', host, port);

});
