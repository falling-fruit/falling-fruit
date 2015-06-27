var db = require('./db');
var express = require('express');
var app = express();
var promise = require("bluebird");

app.get('/locations/markers.json', function (req, res) {
  db.pg.connect(db.conString, function(err, client, done) {
    if (err) return console.error('error fetching client from pool', err);
    client.query("SELECT COUNT(*) FROM locations WHERE user_id=$1;",[1],function(err, result) {
      if (err) return console.error('error running query', err);
      res.send(result.rows[0]);
    });
  });
});

var server = app.listen(3100, function () {

  var host = server.address().address;
  var port = server.address().port;

  console.log('Falling Fruit API listening at http://%s:%s', host, port);

});
