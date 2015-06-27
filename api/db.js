var yaml = require('js-yaml');
var fs   = require('fs');

var db = {};
var rails_env = "development";
var dbconf;

try {
  dbconf = yaml.safeLoad(fs.readFileSync('../config/database.yml', 'utf8'));
  dbconf = dbconf[rails_env];
} catch (e) {
  console.log(e);
}

db.pg = require('pg');
db.conString = "postgres://"+dbconf["username"]+":"+
               dbconf["password"]+"@"+dbconf["host"]+"/"+dbconf["database"];

module.exports = db;
