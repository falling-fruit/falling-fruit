// globals
config = require('./config');
db = require('./db');
async = require("async");
__ = require("underscore");
_s = require("underscore.string");
common = require('./common');

// locals
var express = require('express');
var apicache = require('apicache').options({ debug: true }).middleware;
var multer = require('multer');

var app = express();
app.use(multer({ dest: config.temp_dir }));

app.use(function(req, res, next) {
  res.header("Access-Control-Allow-Origin", "*");
  res.header("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");
  next();
});

// TODO: GET /locations/mine.json - 0.3

// Note: /locations/marker.json is now obsolete (covered by /locations/:id.json)
// Note: /locations/nearby.json is now obsolete (covered by /locations.json)

// Routes
var auth = require('./auth');
var types = require('./types');
var locations = require('./locations');
var clusters = require('./clusters');
var reviews = require('./reviews');

// Note: takes email/password, returns authentication_token (in hash) -- protocol may have changed
app.get('/login.json',auth.login);
app.get('/logout.json',auth.logout);

// Note: grid parameter replaced by zoom
// Note: now can accept a bounding box, obviating the cluster_types.json endpoint
app.get('/types.json',apicache('1 hour'),types.list);

// Note: GET /locations.json replaces both /markers.json and nearby.json
// Note: types renamed to type_ids
// Note: n renamed to limit
// Note: name (string) replaced with type_names (array)
// Note: title removed (client can create from type_names)
// Note: can take lat/lng to obviate need for nearby.json
// Note: returns only the most recent photo, not an array of photos
// FIXME: does not include child types, leaves it to the client to do that with t argument
app.get('/locations.json', locations.list);
// NOTE: title has been replaced with type_names
app.get('/locations/:id(\\d+).json', locations.show);
// Note: only logs change as addition (not review too, when both are done)
app.post('/locations.json',locations.add);
app.post('/locations/:id(\\d+).json',locations.edit);

// Note: grid param renamed to zoom
// Note: does not implicitly include children, we leave that to the client
// Note: does not return title, client is responsible for formatting (i.e., calling number_to_human)
app.get('/clusters.json', clusters.list);

app.get('/locations/:id(\\d+)/reviews.json', reviews.list);
// Note: only logs change as addition (not review too, when both are done)
app.post('/locations/:id(\\d+)/review.json',reviews.add);

var server = app.listen(config.port, function () {

  var host = server.address().address;
  var port = server.address().port;

  console.log('Falling Fruit API listening at http://%s:%s', host, port);

});
