var types = {};

types.list = function (req, res) {
  // Bounds
  var bounds = [req.query.swlng, req.query.nelng, req.query.swlat, req.query.nelat];
  var has_bounds = __.every(bounds);
  if (has_bounds) {
    bounds = bounds.map(function(x) { return parseFloat(x) });
    sw_xy = common.wgs84_to_web_mercator(bounds[0], bounds[2]);
    ne_xy = common.wgs84_to_web_mercator(bounds[1], bounds[3]);
    bounds = [sw_xy[0], ne_xy[0], sw_xy[1], ne_xy[1]];
  }
  // Zoom
  var zoom = req.query.zoom ? parseInt(req.query.zoom) : 0;
  if (zoom > 12 || zoom < 0) {
    return common.send_error(res, 'Zoom must be in the interval [0, 12]');
  }
  if (zoom > 3) {
    zoom += 1;
  }
  // Categories
  var category_mask = common.default_catmask;
  if (req.query.c) {
    category_mask = common.catmask(req.query.c.split(","));
  }
  // Filters
  var filters = {
    pending: req.query.pending == "1" ?
      null :
      "NOT pending",
    categories: "((category_mask & " + category_mask + ") > 0" +
      (req.query.uncategorized == "1" ? " OR category_mask = 0 OR category_mask IS NULL" : "") +
      ")"
  };
  if (has_bounds) {
    filters.bounds = [
      "(x > " + bounds[0] +
      (bounds[1] > bounds[0] ? " AND " : " OR ") +
      "x < " + bounds[1] + ")",
      "y > " + bounds[2], "y < " + bounds[3]
    ].join(" AND ");
    filters.zoom = "zoom = " + zoom;
    filters.muni = req.query.muni == "1" ?
      null :
      "NOT muni";
  }
  var filter_str = __.reject(filters, __.isNull).join(" AND ");
  // Fields
  var name = req.query.locale ? common.i18n_name(req.query.locale) : "en_name";
  var fields = [
    "id",
    "scientific_name", "scientific_synonyms",
    "COALESCE(" + name + ") as name", "en_name", "en_synonyms",
    "es_name", "he_name", "pl_name", "fr_name", "pt_br_name",
    "de_name", "it_name", "el_name", "nl_name", "zh_tw_name",
    "pending", "taxonomic_rank", "category_mask"
  ];
  var urls = [
    "usda_symbol", "wikipedia_url", "eat_the_weeds_url", "foraging_texas_url",
    "urban_mushrooms_url", "fruitipedia_url"
  ];
  if (req.query.urls == "1") {
    fields = fields.concat(urls);
  }
  var field_str = fields.join(", ");
  // Order
  var order_str = ["scientific_name", "taxonomic_rank", "name"].join(", ");
  // Query
  db.pg.connect(function(err, client, done) {
    if (err) {
      common.send_error(res, 'error fetching client from pool', err);
      return done();
    }
    async.waterfall([
      function(callback) {
        common.check_api_key(req, client, callback)
      },
      function(callback) {
        if (has_bounds) {
          client.query(
            [
              "SELECT t." + field_str + ", SUM(count) as count",
              "FROM types t, clusters c WHERE c.type_id = t.id AND", filter_str,
              "GROUP BY t.id, name, scientific_name",
              "ORDER BY", order_str
            ].join(" "),
            function(err, result) {
              if (err) {
                return callback(err, 'Error running query');
              }
              res.send(__.map(result.rows, function(x) {
                x.count = parseInt(x.count);
                return x;
              }));
              return callback(null);
            }
          );
        } else {
          client.query(
            [
              "SELECT", field_str,
              "FROM types WHERE", filter_str,
              "ORDER BY", order_str
            ].join(" "),
            function(err, result) {
              if (err) {
                return callback(err, 'Error running query');
              }
              res.send(result.rows);
              return callback(null);
            }
          );
        }
      }
    ],
    function(err, message) {
      done();
      if (message) {
        common.send_error(res, message, err);
      }
    }
  );
  });
};

types.show = function (req, res) {
  var id = parseInt(req.params.id);
  db.pg.connect(function(err, client, done) {
    if (err) {
      common.send_error(res, 'Error fetching client from pool', err);
      return done();
    }
    async.waterfall([
      function(callback) {
        common.check_api_key(req, client, callback)
      },
      function(callback) {
        client.query(
          "SELECT * FROM types WHERE id=$1;", [id],
          function(err, result) {
            if (err) {
              callback(err, 'Error running query');
            }
            if (result.rowCount == 0) {
              return res.send({});
            }
            res.send(result.rows[0]);
          }
        );
      },
      function(callback) {
        common.log_api_call("GET", "/types/:id.json", 1, req, client, callback);
      }
    ],
    function(err, message){
      done();
      if (message) {
        common.send_error(res, message, err);
      }
    });
  });
};

module.exports = types;
