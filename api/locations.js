var locations = {};

function addTitleToLocation(location) {
  if (location.type_names) {
    var names = location.type_names.slice(0, 2);

    if (location.type_names.length > 2) {
      names.push("...");
    }

    location.title = names.join(', ');
  }

  return location;
}

locations.add = function (req, res) {
  db.pg.connect(db.conString, function(err, client, done) {
    if (err){ 
      common.send_error(res,'error fetching client from pool',err);
      return done();
    }
    // 1. check api key
    // 2. authenticate
    // 3. do location insert
    // 4. get inserted id
    // 5. do change insert
    // 6. do observation insert & send response
    // 7. do api log insert
    // [8. get observation id]
    // [9. resize and upload photo]
    // 10. respond to user
    //
    async.waterfall([
      function(callback){ common.check_api_key(req,client,callback); },
      function(callback){ common.authenticate_by_token(req,client,callback); },
      function(user,callback){
        var author = req.query.author ? req.query.author : (user.add_anonymously ? null : user.name);
        var coords = common.sanitize_wgs84_coords(req.query.lat,req.query.lng);
        client.query("INSERT INTO locations (author,description,type_ids,\
                      lat,lng,season_start,season_stop,no_season,unverified,access,\
                      location,created_at,updated_at) \
                      VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,\
                      ST_SetSRID(ST_POINT($11,$12),4326),CURRENT_TIMESTAMP,CURRENT_TIMESTAMP);",
                     [author,req.query.description,req.query.type_ids.split(","),
                      req.query.lat,req.query.lng,req.query.season_start,req.query.season_stop,
                      req.query.no_season,req.query.unverified,
                      req.query.access,coords[1],coords[0]],function(err,result){
          
          if(err) return callback(err,'error running query');
          else return callback(null,user);
        });
      },
      function(user,callback){
        client.query("SELECT currval('locations_id_seq') as id;",[],function(err,result){
          if(err) return callback(err,'error running query');
          else return callback(null,parseInt(result.rows[0].id),user);
        });
      },
      function(location_id,user,callback){
        // change log
        client.query("INSERT INTO changes (location_id,user_id,description,created_at,updated_at) \
                      VALUES ($1,$2,$3,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP);",
                     [location_id,user.id,"added"],function(err,result){
          if(err) return callback(err,'error running query');
          else return callback(null,location_id,user);
        });
      },
      function(location_id,user,callback){
        if(__.some([req.query.comment,req.query.fruiting,req.query.quality_rating,
                    req.query.yield_rating,req.query.photo_data])){
          // FIXME: fetch location_id from last result
          // FIXME: parse photo data and upload to amazon (recreate paperclip!?)
          client.query("INSERT INTO observations (location_id,author,comment,yield_rating,\
                        quality_rating,fruiting,photo_file_name,observed_on,created_at,updated_at) \
                        VALUES (currval('locations_id_seq'),$1,$2,$3,$4,$5,$6,$7,\
                        CURRENT_TIMESTAMP,CURRENT_TIMESTAMP);",
                       [req.query.author,req.query.comment,req.query.yield_rating,req.query.quality_rating,
                        req.query.fruiting,req.query.photo_file_name,req.query.observed_on],
                       function(err,result){
            if(err) return callback(err,'error running query');
            return callback(null,location_id,user);
          });
        }else{
          res.send({"location_id": location_id });
          return callback('okay','done'); // jump to the finish line
        }
      },
      function(location_id,user,callback){
        client.query("SELECT currval('observations_id_seq') as id;",[],function(err,result){
          if(err) return callback(err,'error running query');
          else return callback(null,location_id,parseInt(result.rows[0].id),user);
        });
      },
      function(location_id,observation_id,user,callback){
        console.log('Photo Data:',req.files.photo_data);
        if(req.files.photo_data){
          var info = req.files.photo_data;
          return common.resize_and_upload_photo(info.path,req.query.photo_file_name,observation_id,location_id,callback);
        }else{
          return callback(null,location_id,observation_id,null);
        }
      },
      function(location_id,observation_id,images,callback){
        var ret = {"location_id": location_id, "observation_id": observation_id };
        if(images) ret.images = images;
        res.send(ret);
        return callback(null);
      }
    ],
    function(err,message){
      done();
      if(message && (err != 'okay')) common.send_error(res,message,err);
    }); 
  });
};

locations.edit = function (req, res) {
  var id = parseInt(req.params.id);
  db.pg.connect(db.conString, function(err, client, done) {
    if (err){ 
      common.send_error(res,'error fetching client from pool',err);
      return done();
    }
    // 1. check api key
    // 2. authenticate
    // 3. do location update
    // 4. do change insert
    //
    async.waterfall([
      function(callback){ common.check_api_key(req,client,callback); },
      function(callback){ common.authenticate_by_token(req,client,callback); },
      function(user,callback){
        var author = req.query.author ? req.query.author : (user.add_anonymously ? null : user.name);
        var coords = common.sanitize_wgs84_coords(req.query.lat,req.query.lng);
        client.query("UPDATE locations SET (description,type_ids,\
                      lat,lng,season_start,season_stop,no_season,unverified,access,\
                      location,updated_at) = \
                      ($1,$2,$3,$4,$5,$6,$7,$8,$9,\
                      ST_SetSRID(ST_POINT($10,$11),4326),CURRENT_TIMESTAMP) WHERE id=$12;",
                     [req.query.description,req.query.type_ids.split(","),
                      req.query.lat,req.query.lng,req.query.season_start,req.query.season_stop,
                      req.query.no_season,req.query.unverified,
                      req.query.access,coords[1],coords[0],id],function(err,result){
          
          if(err) return callback(err,'error running query');
          else return callback(null,id,user);
        });
      },
      function(location_id,user,callback){
        // change log
        client.query("INSERT INTO changes (location_id,user_id,description,created_at,updated_at) \
                      VALUES ($1,$2,$3,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP);",
                     [location_id,user.id,"edited"],function(err,result){
          if(err) return callback(err,'error running query');
          else return res.send({"location_id": location_id });
        });
      }
    ],
    function(err,message){
      done();
      if(message) common.send_error(res,message,err);
    }); 
  });
};

locations.list = function (req, res) {
  var cmask = common.default_catmask;
  if(req.query.c) cmask = common.catmask(req.query.c.split(","));
  var cfilter = "(bit_or(t.category_mask) & "+cmask+")>0";

  var name = "name";
  if(req.query.locale) name = common.i18n_name(req.query.locale); 

  var mfilter = "";
  if(req.query.muni == 0) mfilter = "AND NOT muni";

  var ifilter = "";
  if(req.query.invasive) {
    if (req.query.invasive == 1) ifilter = "AND invasive";
    else if (req.query.invasive == 0) ifilter = "AND NOT invasive";
  }

  var bfilter = undefined;
  if (__.every([req.query.swlat, req.query.swlng, req.query.nelat, req.query.nelng])) {
    bfilter = common.postgis_bbox(
      "location",
      parseFloat(req.query.nelat),
      parseFloat(req.query.nelng),
      parseFloat(req.query.swlat),
      parseFloat(req.query.swlng),
      4326,
      12
    );
  } else {
    return common.send_error(res,'bounding box not defined');
  }

  var columns = [];
  var sorted = "1 as sort";
  var sorts = ["sort asc"];

  if (req.query.t) {
    var tids = __.map(req.query.t.split(","), function(x) {
      return parseInt(x)
    });

    sorted = "CASE WHEN array_agg(t.id) @> ARRAY["
      + tids + "] THEN 0 ELSE 1 END as sort";
  }

  var limit = req.query.limit ?
    __.min([parseInt(req.query.limit),1000]) :
    1000;

  var offset = req.query.offset ?
    parseInt(req.query.offset) :
    0;

  var filters = __.reject([bfilter,mfilter,ifilter], __.isUndefined)
    .join(" ");

  var distance = "";
  if(__.every([req.query.lat, req.query.lng])){
    var coords = common.sanitize_wgs84_coords(req.query.lat,req.query.lng);

    columns.push(
      "ST_Distance(l.location,ST_SETSRID(ST_POINT("+coords[1]+
        ","+coords[0]+"),4326)) as distance"
    );

    sorts.push("distance asc");
  }

  var reviews = "";
  if (req.query.reviews == 1) {
    columns.push(
      ",(SELECT COUNT(*) FROM observations o1 WHERE o1.location_id=l.id) AS num_reviews,\
        (SELECT photo_file_name || '/' || id FROM observations o2 WHERE o2.location_id=l.id AND \
        photo_file_name IS NOT NULL \
        ORDER BY photo_file_name DESC LIMIT 1) as photo_file_name"
    );
  }

  db.pg.connect(db.conString, function(err, client, done) {
    if (err) {
      common.send_error(res,'error fetching client from pool',err);
      return done();
    }

    async.waterfall([
      function(callback) { common.check_api_key(req,client,callback) },
      function(callback) {
        client.query(
          "SELECT COUNT(*) FROM locations l, types t " +
            "WHERE t.id=ANY(l.type_ids) " +
            filters + ";",
          [],
          function(err,result){
            if (err) {
              callback(err, 'error running query');
            } else {
              callback(null,parseInt(result.rows[0].count));
            }
          }
        );
      },
      function(total_count,callback) {
        columns = columns.concat([
          "l.id",
          "l.lat",
          "l.lng",
          "l.unverified",
          "l.type_ids",
          "l.description",
          "l.author",
          "ARRAY_AGG(COALESCE(" + name + ", name)) AS type_names",
          sorted
        ]);

        var sql = "SELECT " + columns.join(', ') + " \
            FROM locations l, types t \
            WHERE t.id = ANY(l.type_ids) " + filters + " \
            GROUP BY l.id, l.lat, l.lng, l.unverified \
            HAVING " + cfilter + " \
            ORDER BY " + sorts.join(', ') + " LIMIT $1 OFFSET $2; \
          ";

        client.query(sql, [limit, offset], function (err, result) {
          if (err) { return callback(err, 'error running query'); }
          var responseJson = [result.rowCount, total_count];

          responseJson = responseJson.concat(
            __.map(result.rows, function(x) {
              if (x.num_reviews) {
                x.num_reviews = parseInt(x.num_reviews);
              }

              if (x.photo_file_name) {
                var parts = x.photo_file_name.split("/");

                x.photo = common.photo_urls(parts[1], parts[0]);
                x.photo_file_name = parts[0];
              }

              x = addTitleToLocation(x);

              return x;
            })
          );

          res.send(responseJson);
          callback(null, result.rowCount);
        });
      },
      function(n, callback) {
        common.log_api_call("GET","/locations.json",n,req,client,callback);
      }
    ], function(err, message) {
      done();
      if(message) { common.send_error(res, message, err); }
    });
  });
};

locations.show = function (req, res) {
  var id = parseInt(req.params.id);
  var name = "name";

  if (req.query.locale) {
    name = common.i18n_name(req.query.locale);
  }

  db.pg.connect(db.conString, function(err, client, done) {
    if (err) {
      common.send_error(res,'error fetching client from pool',err);
      return done();
    }
    async.waterfall([
      function(callback){ common.check_api_key(req,client,callback) },
      function(callback){
        var columns = [
          "id",
          "season_start",
          "season_stop",
          "access",
          "address",
          "author",
          "created_at",
          "updated_at",
          "city",
          "state",
          "country",
          "description",
          "lat",
          "lng",
          "muni",
          "type_ids",
          "unverified",
          "(SELECT ARRAY_AGG(COALESCE("+name+",name)) FROM types t \
             WHERE ARRAY[t.id] <@ l.type_ids) as type_names",
          "(SELECT COUNT(*) FROM observations o \
            WHERE o.location_id = l.id) as num_reviews",
        ];

        var sql = "SELECT " + columns.join(', ') + " \
          FROM locations l WHERE id = $1";

        client.query(sql, [id], function(err, result) {
          if (err) callback(err,'error running query');
          if (result.rowCount == 0) return res.send({});

          location = result.rows[0];
          location.num_reviews = parseInt(location.num_reviews);

          var photoQuery = "SELECT id, photo_updated_at, photo_file_name \
            FROM observations \
            WHERE photo_file_name IS NOT NULL AND location_id = $1";

          client.query(photoQuery, [id] ,function(err, result) {
            if (err) return callback(err,'error running query');

            location.photos = __.map(result.rows, function(x){
              x.photo = common.photo_urls(x.id, x.photo_file_name);
              return x;
            });

            x = addTitleToLocation(x);

            res.send(location);
          });
        });
      },
      function(callback) {
        common.log_api_call(
          "GET",
          "/locations/:id.json",
          1,
          req,
          client,
          callback
        );
      }
    ],
    function (err, message) {
      done();
      if(message) common.send_error(res,message,err);
    });
  });
};

module.exports = locations;
