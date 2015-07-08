var reviews = {};

reviews.add = function (req, res) {
  // FIXME: verify this is a real location id
  var location_id = parseInt(req.params.id);
  db.pg.connect(db.conString, function(err, client, done) {
    if (err){ 
      common.send_error(res,'error fetching client from pool',err);
      return done();
    }
    // 1. check api key
    // 2. authenticate
    // 3. do change insert
    // 4. do observation insert
    // 5. get observation id
    // 6. [resize and upload photo]
    // 7. send response
    async.waterfall([
      function(callback){ common.check_api_key(req,client,callback); },
      function(callback){ common.authenticate_by_token(req,client,callback); },
      function(user,callback){
        var author = req.query.author ? req.query.author : (user.add_anonymously ? null : user.name);
        // change log
        client.query("INSERT INTO changes (location_id,user_id,description,created_at,updated_at) \
                      VALUES ($1,$2,$3,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP);",
                     [location_id,user.id,"visited"],function(err,result){
          if(err) return callback(err,'error running query');
          else return callback(null,user);
        });
      },
      function(user,callback){
        if(__.some([req.query.comment,req.query.fruiting,req.query.quality_rating,
                    req.query.yield_rating,req.query.photo_data])){
          // FIXME: parse photo data and upload to amazon (recreate paperclip!?)
          client.query("INSERT INTO observations (location_id,author,comment,yield_rating,\
                        quality_rating,fruiting,photo_file_name,observed_on,created_at,updated_at) \
                        VALUES ($1,$2,$3,$4,$5,$6,$7,$8,\
                        CURRENT_TIMESTAMP,CURRENT_TIMESTAMP);",
                       [location_id,req.query.author,req.query.comment,
                        req.query.yield_rating,req.query.quality_rating,
                        req.query.fruiting,req.query.photo_file_name,req.query.observed_on],
                       function(err,result){
            if(err) return callback(err,'error running query');
            else return callback(null,user);
          });
        }else{
          return callback(err,'missing fields');
        }
      },
      function(user,callback){
        client.query("SELECT currval('observations_id_seq') as id;",[],function(err,result){
          if(err) return callback(err,'error running query');
          else return callback(null,parseInt(result.rows[0].id),user);
        });
      },
      function(observation_id,user,callback){
        console.log('Photo Data:',req.files.photo_data);
        if(req.files.photo_data){
          var info = req.files.photo_data;
          common.resize_and_upload_photo(info.path,req.query.photo_file_name,observation_id,location_id,callback);
        }else{
          callback(null,location_id,observation_id,null);
        }
      },
      function(location_id,observation_id,images,callback){
        var ret = {"location_id": location_id, "observation_id": observation_id };
        if(images) ret.images = images;
        res.send(ret);
      }
    ],
    function(err,message){
      done();
      if(message) common.send_error(res,message,err);
    }); 
  });
};

reviews.list = function (req, res) {
  var id = req.params.id;
  db.pg.connect(db.conString, function(err, client, done) {
    if (err){ 
      send_error(res,'error fetching client from pool',err);
      return done();
    }
    async.waterfall([
      function(callback){ common.check_api_key(req,client,callback) },
      function(callback){
        client.query("SELECT id, location_id, comment, observed_on, \
                      photo_file_name, fruiting, quality_rating, yield_rating, author, photo_caption \
                      FROM observations WHERE location_id=$1;",
                     [id],function(err, result) {
          if (err) return callback(err,'error running query');
          res.send(__.map(result.rows,function(x){
            x.photo = photo_urls(x.id,x.photo_file_name);
            return x;
          }));
        });
      }
    ],
    function(err,message){
      done();
      if(message) common.send_error(res,message,err);
    });    
  });
};

module.exports = reviews;
