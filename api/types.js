var types = {};

types.list = function (req, res) {
  var cmask = common.default_catmask;
  if(req.query.c) cmask = common.catmask(req.query.c.split(","));
  var cfilter = "";
  if(req.query.uncategorized) cfilter = "category_mask=0 OR category_mask IS NULL OR "; 
  var name = "name";
  if(req.query.locale) name = common.i18n_name(req.query.locale); 
  var mfilter = "";
  if(req.query.muni == 0) mfilter = "AND NOT muni";
  var pfilter = "NOT pending AND";
  if(req.query.pending == 1) pfilter = "";
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
          client.query("SELECT t.id, COALESCE("+name+",name) as name,scientific_name, \
                        es_name, he_name, pl_name, fr_name, pt_br_name, de_name, it_name, \
                        synonyms, scientific_synonyms, pending, taxonomic_rank, category_mask, \
                        SUM(count) as count \
                        FROM types t, clusters c WHERE "+pfilter+" c.type_id=t.id \
                        AND ("+cfilter+"(category_mask & $1)>0) "+filters+" GROUP BY t.id, name, scientific_name \
                        ORDER BY name,scientific_name;",
                       [cmask],function(err, result) {
            if (err) return callback(err,'error running query');
            res.send(__.map(result.rows,function(x){ 
              x.count = parseInt(x.count); 
              return x; 
            }));
            return callback(null);
          });
        }else{
          client.query("SELECT id, COALESCE("+name+",name) as name,scientific_name, \
                        es_name, he_name, pl_name, fr_name, pt_br_name, de_name, it_name, \
                        synonyms, scientific_synonyms, pending, taxonomic_rank, category_mask \
                        FROM types WHERE "+pfilter+" ("+cfilter+"(category_mask & $1)>0) \
                        ORDER BY name,scientific_name;",
                       [cmask],function(err, result) {
            if (err) return callback(err,'error running query');
            res.send(result.rows);
            return callback(null);
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