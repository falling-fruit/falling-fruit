var db = require('./db');
var async = require("async");
var __ = require("underscore");
var express = require('express');
var apicache = require('apicache').options({ debug: true }).middleware;
var app = express();

// Helper functions
function catmask(cats){
  var options = ["forager","freegan","honeybee","grafter"];
  return __.reduce(__.pairs(options),function(memo,pair){
    return memo | (__.contains(cats,pair[1]) ? 1<<parseInt(pair[0]) : 0)
  },0);
}
var default_catmask = catmask(["forager","freegan"]);

function i18n_name(locale){
  if(__.contains(["es","he","pt","it","fr","de","pl"],locale)) return locale + "_name";
  else return "name";
}

function encrypt_password(clear){
  // FIXME: need to match devise's encrypt method
  return clear;
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
      callback(null); // pass
    }
  });
}

function authenticate_by_token(req,client,callback){
  if(!req.query.auth_token) return callback(true,'authentication (auth_token) required');
  client.query("SELECT id, email, add_anonymously, name FROM users WHERE authentication_token=$1;",
               [req.query.auth_token],function(err, result) {
    if (err) callback(err,'error running query');
    if(result.rowCount == 0){
      callback(true,'auth token is invalid');
    }else{
      callback(null,result.rows[0]); // pass
    }
  });
}

//  def log_api_request(endpoint,n)
//    a = ApiLog.new
//    a.n = n
//    a.endpoint = endpoint
//    begin
//      a.params = Base64.encode64(Marshal.dump(params))
//    rescue StandardError => bang
//      a.params = nil
//    end
//    a.request_method = request.request_method
//    a.ip_address = request.remote_ip
//    a.api_key = params[:api_key] if params[:api_key].present?
//    a.save
//  end
//  helper_method :log_api_request


function log_api_call(endpoint,n,user,req,client,callback){
  var params = req.query; // FIXME: serialize and b64encode
  var method = req.query; // FIXME: determine request method
  var ip = req.query; // FIXME: determine ip
  client.query("INSERT INTO api_log (n,endpoint,params,request_method,\
                ip_address,api_key) VALUES ($1,$2,$3,$4,$5,$6);",
               [n,endpoint,params,method,ip,req.query.api_key],function(err, result) {
    if (err) return callback(err,'error running query');
    return callback(null); // pass
  });
}

// Routes

// FIXME: CORS enabled

// TODO: PUT /locations/:id.json (edit location) - 0.2
// TODO: POST /locations.json (add location) - 0.2
// TODO: POST /locations/:id/reviews.json (add review) - 0.2
// TODO: GET /locations/mine.json - 0.3

// Note: /locations/marker.json is now obsolete (covered by /locations/:id.json)
// Note: /locations/nearby.json is now obsolete (covered by /locations.json)

//def prepare_observation(obs_params,loc)
//    return nil if obs_params.nil? or obs_params.values.all?{|x| x.blank? }

//    # deal with photo data in expected JSON format
//    # (as opposed to something already caught and parsed by paperclip)
//    unless obs_params["photo_data"].nil?
//      tempfile = Tempfile.new("fileupload")
//      tempfile.binmode
//      data = obs_params["photo_data"]["data"].include?(",") ? obs_params["photo_data"]["data"].split(/,/)[1] : obs_params["photo_data"]["data"]
//      tempfile.write(Base64.decode64(data))
//      tempfile.rewind
//      uploaded_file = ActionDispatch::Http::UploadedFile.new(
//        :tempfile => tempfile,
//        :type => "image/jpeg",
//        :filename => "upload.jpg"
//      )
//      obs_params[:photo] = uploaded_file
//      obs_params.delete(:photo_data)
//    end
//    obs = Observation.new(obs_params)
//    obs.observed_on = Date.today if obs.observed_on.nil?
//    obs.location = loc
//    obs.user = current_user if user_signed_in?
//    return obs
//  end

//  def log_changes(location,description,observation=nil,author=nil,description_patch=nil,
//    former_type_ids=[],former_location=nil)
//    c = Change.new
//    c.location = location
//    c.description = description
//    c.remote_ip = request.remote_ip
//    c.user = current_user if user_signed_in?
//    c.observation = observation
//    c.description_patch = description_patch
//    c.former_type_ids = former_type_ids
//    c.former_location = former_location
//    # adding an observation
//    if author.nil? and not observation.nil?
//      c.author = observation.author
//    # adding a location
//    elsif author.nil? and observation.nil? and description == "added"
//      c.author = location.author
//    # editing a location
//    elsif not author.nil?
//      c.author = author
//    end
//    c.save
//  end
//  helper_method :log_changes

// Note: only logs change as addition (not review too, when both are done)
app.post('/locations.json', function (req, res) {
  db.pg.connect(db.conString, function(err, client, done) {
    if (err){ 
      send_error(res,'error fetching client from pool',err);
      return done();
    }
    async.waterfall([
      function(callback){ check_api_key(req,client,callback); },
      function(callback){ authenticate_by_token(req,client,callback); },
      function(user,callback){
        var author = req.query.author ? req.query.author : (user.add_anonymously ? null : user.name);
        client.query("INSERT INTO locations (author,description,type_ids,\
                      lat,lng,season_start,season_stop,no_season,unverified,access) \
                      VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,ST_SetSRID(ST_POINT($11,$12),4326));",
                     [author,req.query.description,req.query.type_ids.split(","),
                      req.query.lat,req.query.lng,req.query.season_start,req.query.season_stop,
                      req.query.no_season,req.query.unverified,req.query.access],function(err,result){
          var location_id = result;

          // change log
          client.query("INSERT INTO changes (location_id,user_id,description) VALUES ($1,$2,$3);",
                       [location_id,user.id,"added"],function(err,result){
            if(err) return callback(err,'error running query');
          });

          // proceed with observation if needed
          if(__.some([req.query.comment,req.query.fruiting,req.query.quality_rating,
                      req.query.yield_rating,req.query.photo_data])){
            // FIXME: fetch location_id from last result
            // FIXME: parse photo data and upload to amazon (recreate paperclip!?)

            client.query("INSERT INTO observations (location_id,author,comment,yield_rating,\
                          quality_rating,fruiting,photo_file_name,observed_on) \
                          VALUES ($1,$2,$3,$4,$5,$6,$7);",
                         [req.query.author,req.query.comment,req.query.yield_rating,req.query.quality_rating,
                          req.query.fruiting,req.query.photo_file_name,req.query.observed_on],
                         function(err,result){
              if(err) return callback(err,'error running query');
              res.send({"location_id": location_id, "review": true });
              return callback(null,user,2);
            });
          }else{
            res.send({"location_id": location_id });
            return callback(null,user,1);
          }
        });
      },
      function(user,n,callback){ log_api_call("/locations.json",n,user,req,client,callback); }
    ],
    function(err,message){
      done();
      if(message) send_error(res,message,err);
    }); 
  });
});

// Note: takes email/password, returns authentication_token (in hash) -- protocol may have changed
app.get('/login.json', function (req, res) {
  var email = req.query.email;
  var password = encrypt_password(req.query.password);
  db.pg.connect(db.conString, function(err, client, done) {
    if (err){ 
      send_error(res,'error fetching client from pool',err);
      return done();
    }
    async.waterfall([
      function(callback){ check_api_key(req,client,callback) },
      function(callback){
        client.query("SELECT authentication_token FROM users WHERE email=$1 AND encrypted_password=$2;",
                     [email,password],function(err,result){
          if (err) return callback(err,'error running query');
          if (result.rowCount == 0) return callback(true,'bad email or password');
          return res.send(result.rows[0]);
        });
      }
    ],
    function(err,message){
      done();
      if(message) send_error(res,message,err);
    }); 
  });
});

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
            if (err) return callback(err,'error running query');
            res.send(__.map(result.rows,function(x){ 
              x.count = parseInt(x.count); 
              return x; 
            }));
          });
        }else{
          client.query("SELECT id, COALESCE("+name+",name) as name,scientific_name FROM types WHERE NOT \
                        pending AND (category_mask & $1)>0 ORDER BY name,scientific_name;",
                       [cmask],function(err, result) {
            if (err) return callback(err,'error running query');
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
          if (err) return callback(err,'error running query');
          res.send([result.rowCount,total_count].concat(__.map(result.rows,function(x){
            if(x.num_reviews) x.num_reviews = parseInt(x.num_reviews);
            return x;
          })));
        });
      }
    ],
    function(err,message){
      done();
      if(message) send_error(res,message,err);
    }); 
  });
});

// Note: grid param renamed to zoom
// Note: does not implicitly include children, we leave that to the client
// Note: does not return title, client is responsible for formatting (i.e., calling number_to_human)
app.get('/clusters.json', function (req, res) {
  var cmask = default_catmask;
  if(req.query.c) cmask = catmask(req.query.c.split(",")); 
  var cfilter = "(bit_or(t.category_mask) & "+cmask+")>0";
  var mfilter = "";
  if(req.query.muni == 0) mfilter = "AND NOT muni";
  var bfilter = undefined;
  var zfilter = "zoom=2"; // zfilter is first so doesn't have an AND
  if(__.every([req.query.swlat,req.query.swlng,req.query.nelat,req.query.nelng])){
    bfilter = postgis_bbox("cluster_point",parseFloat(req.query.nelat),parseFloat(req.query.nelng),
                           parseFloat(req.query.swlat),parseFloat(req.query.swlng),900913);
    if(req.query.zoom) zfilter = "zoom="+parseInt(req.query.zoom);
  }else{
    return send_error(res,'bounding box not defined');    
  }
  var tfilter = "AND type_id IS NULL";
  if(req.query.t){
    var tids = __.map(req.query.t.split(","),function(x){ parseInt(x) });
    tfilter = "AND type_id IN ("+tids.join(",")+")";
  }
  var filters = __.reject([zfilter,tfilter,bfilter,mfilter],__.isUndefined).join(" ");
  db.pg.connect(db.conString, function(err, client, done) {
    if (err){ 
      send_error(res,'error fetching client from pool',err);
      return done();
    }
    async.waterfall([
      function(callback){ check_api_key(req,client,callback) },
      function(callback){
        client.query("SELECT ST_X(center_point) AS center_x, ST_Y(center_point) AS center_y, count FROM \
                      (SELECT ST_Transform(ST_SetSRID(ST_POINT(SUM(count*ST_X(cluster_point))/SUM(count), \
                      SUM(count*ST_Y(cluster_point))/SUM(count)),900913),4326) as center_point, \
                      SUM(count) as count FROM clusters WHERE "+filters+" GROUP BY grid_point) subq;",
                     [],function(err, result) {
          if (err) return callback(err,'error running query');
          res.send(__.map(result.rows,function(x){
            x.count = parseInt(x.count);
            return x;
          }));
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
            if (err) return callback(err,'error running query');
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
          if (err) return callback(err,'error running query');
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

var server = app.listen(3100, function () {

  var host = server.address().address;
  var port = server.address().port;

  console.log('Falling Fruit API listening at http://%s:%s', host, port);

});
