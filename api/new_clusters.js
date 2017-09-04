var new_clusters = {};

new_clusters.list = function(req, res) {
  // Type_ids
  var type_ids = [];
  if (req.query.t) {
    type_ids = req.query.t.split(",").map(function(x) { return parseInt(x) });
  }
  // Bounds
  var bounds = [req.query.swlng, req.query.nelng, req.query.swlat, req.query.nelat];
  if (__.every(bounds)) {
    bounds = bounds.map(function(x) { return parseFloat(x) });
    sw_xy = common.wgs84_to_web_mercator(bounds[0], bounds[2]);
    ne_xy = common.wgs84_to_web_mercator(bounds[1], bounds[3]);
    bounds = [sw_xy[0], ne_xy[0], sw_xy[1], ne_xy[1]];
  } else {
    return common.send_error(res, 'Bounding box not defined');
  }
  // Zoom
  var zoom = req.query.zoom ? parseInt(req.query.zoom) : 0;
  if (zoom > 12 || zoom < 0) {
    return common.send_error(res, 'Zoom must be in the interval [0, 12]');
  }
  if (zoom > 3) {
    zoom += 1;
  }
  // Filters
  var filters = {
    muni: req.query.muni == "1" ?
      null :
      "NOT muni",
    type_ids: type_ids.length > 0 ?
      "type_id IN (" + type_ids.join(",") + ")" :
      null, // "type_id IS NULL"
    zoom: "zoom = " + zoom,
    bounds: [
      "(x > " + bounds[0] +
      (bounds[1] > bounds[0] ? " AND " : " OR ") +
      "x < " + bounds[1] + ")",
      "y > " + bounds[2], "y < " + bounds[3]
    ].join(" AND ")
  };
  var filter_str = __.reject(filters, __.isNull).join(" AND ");
  // Query
  var query_str = " \
    SELECT ST_X(center) as lng, ST_Y(center) as lat, count \
    FROM ( \
      SELECT \
        SUM(count) as count, \
        ST_Transform(ST_SetSRID(ST_POINT( \
          SUM(count * x) / SUM(count), SUM(count * y) / SUM(count) \
        ), 900913), 4326) as center \
      FROM new_clusters \
      WHERE " + filter_str + " \
      GROUP BY geohash \
    ) subq; \
  ";
  console.log(filter_str);
  console.log(query_str);
  db.pg.connect(db.conString, function(err, client, done) {
    if (err) {
      common.send_error(res, 'Error fetching client from pool', err);
      return done();
    }
    async.waterfall([
      function(callback) {
        common.check_api_key(req, client, callback)
      },
      function(callback) {
        console.log("Running query");
        client.query(query_str, [], function(err, result) {
          if (err) {
            console.log(err.stack);
            return callback(err, 'Error running query');
          }
          console.log("Sending result")
          res.send(__.map(result.rows, function(x) {
            x.count = parseInt(x.count);
            return x;
          }));
          console.log("Leaving waterfall and cleaning up");
          return callback(null);
        });
      }
    ],
    function(err, message) {
      done();
      if (message) {
        common.send_error(res,message,err);
      }
    });
  });
};

module.exports = new_clusters;
