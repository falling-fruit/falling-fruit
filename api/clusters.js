var clusters = {};

clusters.list = function (req, res) {
  var cmask = common.default_catmask;
  if(req.query.c) cmask = common.catmask(req.query.c.split(",")); 
  var cfilter = "(bit_or(t.category_mask) & "+cmask+")>0";
  var mfilter = "";
  if(req.query.muni == 0) mfilter = "AND NOT muni";
  var bfilter = undefined;
  var zfilter = "zoom=2"; // zfilter is first so doesn't have an AND
  if(__.every([req.query.swlat,req.query.swlng,req.query.nelat,req.query.nelng])){
    bfilter = common.postgis_bbox("cluster_point",parseFloat(req.query.nelat),parseFloat(req.query.nelng),
                           parseFloat(req.query.swlat),parseFloat(req.query.swlng),900913);
    if(req.query.zoom) zfilter = "zoom="+parseInt(req.query.zoom);
  }else{
    return common.send_error(res,'bounding box not defined');    
  }
  var tfilter = "AND type_id IS NULL";
  if(req.query.t){
    var tids = __.map(req.query.t.split(","),function(x){ return parseInt(x) });
    tfilter = "AND type_id IN ("+tids.join(",")+")";
  }
  console.log(req.query.t);
  var filters = __.reject([zfilter,tfilter,bfilter,mfilter],__.isUndefined).join(" ");
  db.pg.connect(db.conString, function(err, client, done) {
    if (err){ 
      common.send_error(res,'error fetching client from pool',err);
      return done();
    }
    async.waterfall([
      function(callback){ common.check_api_key(req,client,callback) },
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
      if(message) common.send_error(res,message,err);
    }); 
  });
};

module.exports = clusters;
