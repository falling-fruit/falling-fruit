// globals
config = require('./config');
db = require('./db');
async = require("async");
__ = require("underscore");
_s = require("underscore.string");
common = require('./common');

// locals
var gm = require('gm');
var fs = require('fs');
var express = require('express');
var apicache = require('apicache').options({ debug: true }).middleware;
var multer = require('multer');

var app = express();
app.use(multer({ dest: config.temp_dir }));

// FIXME: CORS enabled

// TODO: GET /locations/logout.json - 0.2
// TODO: PUT /locations/:id.json (edit location) - 0.2
// TODO: GET /locations/mine.json - 0.3

// Note: /locations/marker.json is now obsolete (covered by /locations/:id.json)
// Note: /locations/nearby.json is now obsolete (covered by /locations.json)

// Routes
var auth = require('./auth');
var types = require('./types');
var locations = require('./locations');
var clusters = require('./clusters');
var reviews = require('./reviews');

app.get('/login.json',auth.login);

app.get('/types.json',apicache('1 hour'),types.list);

app.get('/locations.json', locations.list);
app.get('/locations/:id(\\d+).json', locations.show);
app.post('/locations.json',locations.add);

app.get('/clusters.json', clusters.list);

app.get('/locations/:id(\\d+)/reviews.json', reviews.list);
app.post('/locations/:id(\\d+)/review.json',reviews.add);

var server = app.listen(config.port, function () {

  var host = server.address().address;
  var port = server.address().port;

  console.log('Falling Fruit API listening at http://%s:%s', host, port);

});
