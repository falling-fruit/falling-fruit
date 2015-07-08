var types = {};

types.list = function (req, res) {
  var cmask = common.default_catmask;
  if(req.query.c) cmask = common.catmask(req.query.c.split(",")); 
  var name = "name";
  if(req.query.locale) name = common.i18n_name(req.query.locale); 
  var mfilter = "";
  if(req.query.muni == 0) mfilter = "AND NOT muni";
  var bfilter = undefined;
  var zfilter = "AND zoom=2";
  if(__.every([req.query.swlat,req.query.swlng,req.query.nelat,req.query.nelng])){
    bfilter = common.postgis_bbox("cluster_point",parseFloat(req.query.nelat),parseFloat(req.query.nelng),
                           parseFloat(req.query.swlat),parseFloat(req.query.swlng),900913);
    if(req.query.zoom) zfilter = "AND zoom="+parseInt(req.query.zoom);
  }
  db.pg.connect(db.conString, function(err, client, done) {
    if (err){ 
      common.send_error(res,'error fetching client from pool',err);
      return done();
    }
    async.waterfall([
      function(callback){ common.check_api_key(req,client,callback) },
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
      if(message) common.send_error(res,message,err);
    }); 
  });
}

module.exports = types;
