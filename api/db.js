var yaml = require('js-yaml');
var fs   = require('fs');

var db = {};
var rails_env = "development";
var dbconf;
var s3conf;

// postgres
try {
  dbconf = yaml.safeLoad(fs.readFileSync('../config/database.yml', 'utf8'));
  dbconf = dbconf[rails_env];
} catch (e) {
  console.log(e);
}
db.pg = require('pg');
db.conString = "postgres://"+dbconf["username"]+":"+
               dbconf["password"]+"@"+dbconf["host"]+"/"+dbconf["database"];

// papercut (s3)
try {
  db.s3conf = yaml.safeLoad(fs.readFileSync('../config/s3.yml', 'utf8'));
} catch (e) {
  console.log(e);
}
db.papercut = require('papercut');
db.papercut.configure(rails_env, function(){
  papercut.set('storage', 's3')
  papercut.set('S3_KEY', db.s3conf["access_key_id"])
  papercut.set('S3_SECRET', db.s3conf["secret_access_key"])
  papercut.set('bucket', db.s3conf["bucket"])
});
db.uploader = db.papercut.Schema(function(schema){
  schema.version({
    name: 'thumb',
    size: '100x100',
    process: 'resize'
  });

  schema.version({
    name: 'medium',
    size: '300x300',
    process: 'resize'
  });

  schema.version({
    name: 'original',
    process: 'copy'
  });
});

module.exports = db;
