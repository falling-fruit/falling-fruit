var common = {};

common.gm = require('gm');
common.hat = require('hat');

// Helper functions

// rails paperclip paths are :bucket/observations/photos/:a/:b/:c/medium|thumb|original/whatever.jpg
// :a/:b/:c is from this function and is based on the observation.id
common.id_partition = function(id){
  var ret = _s.sprintf("%09d",parseInt(id));
  return [ret.substr(0,3),ret.substr(3,3),ret.substr(6,3)].join("/");
}

common.photo_urls = function(id,fname,path_only){
  var bucket = db.s3conf.bucket;
  var idpart = common.id_partition(id);
  var urlbase = path_only ? "observations/photos/"+idpart+"/" : 
                            "http://s3-us-west-2.amazonaws.com/"+bucket+"/observations/photos/"+idpart+"/";
  return {"medium": urlbase + "medium/" + fname,
          "original": urlbase + "original/" + fname,
          "thumb": urlbase + "thumb/" + fname};
}

common.catmask = function(cats){
  var options = ["forager","freegan","honeybee","grafter"];
  return __.reduce(__.pairs(options),function(memo,pair){
    return memo | (__.contains(cats,pair[1]) ? 1<<parseInt(pair[0]) : 0)
  },0);
}
common.default_catmask = common.catmask(["forager","freegan"]);

common.i18n_name = function(locale){
  if(__.contains(["es","he","pt","it","fr","de","pl"],locale)) return locale + "_name";
  else return "name";
}

common.postgis_bbox = function(v,nelat,nelng,swlat,swlng,srid){
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

common.send_error = function(res,msg,logmsg){
  res.send({"error": msg});
  console.error("ERROR: ",msg,logmsg);
}

// waterfall-type helpers

common.check_api_key = function(req,client,callback){
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

common.authenticate_by_token = function(req,client,callback){
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

common.generate_auth_token = function(){
  return new Buffer(common.hat()).toString('base64');
}

// Note: currently only GET /locations.json and GET /locations/:id.json are logged
common.log_api_call = function(method,endpoint,n,req,client,callback){
  var params = (new Buffer(JSON.stringify({"query":req.query,
                "params":req.params}))).toString('base64');
  var ip = req.ip;
  client.query("INSERT INTO api_logs (n,endpoint,params,request_method,\
                ip_address,api_key,created_at,updated_at) \
                VALUES ($1,$2,$3,$4,$5,$6,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP);",
               [n,endpoint,params,method,ip,req.query.api_key],function(err, result) {
    if (err){ 
      // if there's an error here, don't tell the user
      console.error('error in log_api_call',err);
      return callback(err,null);
    }
    return callback(null); // pass
  });
}

common.resize_photo = function(size,src_path,dst_path,callback){
  if(size){
    common.gm(src_path)
      .resize(size,size)
      .autoOrient()
      .write(dst_path, function (err) {
        if (err) callback(err,'failed to resize to '+size);
        else callback(null);
      });
  }else{
    common.gm(src_path)
      .autoOrient()
      .write(dst_path, function (err) {
        if (err) callback(err,'failed to resize to '+size);
        else callback(null);
      });
  }
}

common.upload_photo = function(src_path,dst_path,callback){
  var params = {
    localFile: src_path,
    s3Params: {
      Bucket: db.s3conf["bucket"],
      Key: dst_path,
      // other options supported by putObject, except Body and ContentLength. 
      // See: http://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/S3.html#putObject-property 
    },
  };
  var uploader = db.s3client.uploadFile(params);
  uploader.on('error', function(err) {
    callback(err,'unable to upload '+src_path+' to S3');
  });
  uploader.on('progress', function() {
    console.log("progress", uploader.progressMd5Amount,
              uploader.progressAmount, uploader.progressTotal);
  });
  uploader.on('end', function() {
    callback(null); // pass
  });
}

common.resize_and_upload_photo = function(image_path,photo_file_name,observation_id,location_id,outer_callback){
  var thumb_path = config.temp_dir + "/" + observation_id + "-thumb.jpg";
  var medium_path = config.temp_dir + "/" + observation_id + "-medium.jpg";
  var original_path = config.temp_dir + "/" + observation_id + "-original.jpg";
  var dest_paths = common.photo_urls(observation_id,photo_file_name,true);
  async.waterfall([
    function(callback){ common.resize_photo(100,image_path,thumb_path,callback) },
    function(callback){ common.resize_photo(300,image_path,medium_path,callback) },
    function(callback){ common.resize_photo(null,image_path,original_path,callback) },
    function(callback){ common.upload_photo(thumb_path,dest_paths.thumb,callback) },
    function(callback){ common.upload_photo(medium_path,dest_paths.medium,callback) },
    function(callback){ common.upload_photo(original_path,dest_paths.original,callback) }],
    function(err,message){
      if(message) outer_callback(message,err);
      else outer_callback(null,location_id,observation_id,common.photo_urls(observation_id,photo_file_name));
    }); 
}

module.exports = common;
