var yaml = require('js-yaml');
var fs   = require('fs');

var db = {};
var rails_env = "development";
var dbconf;

try {
  dbconf = yaml.safeLoad(fs.readFileSync('../config/database.yml', 'utf8'));
  console.log(dbconf);
  dbconf = dbconf[rails_env];
  console.log(dbconf);
} catch (e) {
  console.log(e);
}

db.pg = require('pg');
db.conString = "postgres://"+dbconf["username"]+":"+
               dbconf["password"]+"@"+dbconf["host"]+"/"+dbconf["database"];
console.log(db.conString);

module.exports = db;
