var yaml = require('js-yaml');
var fs   = require('fs');

var db = {};
var dbconf;
var s3conf;

// postgres
try {
  dbconf = yaml.safeLoad(fs.readFileSync(config.db_config_file, 'utf8'));
  dbconf = dbconf[config.rails_env];
} catch (e) {
  console.log(e);
}
db.pg = require('pg');
db.conString = "postgres://"+dbconf["username"]+":"+
               dbconf["password"]+"@"+dbconf["host"]+"/"+dbconf["database"];

// s3
try {
  db.s3conf = yaml.safeLoad(fs.readFileSync(config.s3_config_file, 'utf8'));
} catch (e) {
  console.log(e);
}
db.s3 = require("s3");
db.s3client = db.s3.createClient({
  maxAsyncS3: 20,     // this is the default 
  s3RetryCount: 3,    // this is the default 
  s3RetryDelay: 1000, // this is the default 
  multipartUploadThreshold: 20971520, // this is the default (20 MB) 
  multipartUploadSize: 15728640, // this is the default (15 MB) 
  s3Options: {
    accessKeyId: db.s3conf["access_key_id"],
    secretAccessKey: db.s3conf["secret_access_key"],
    // any other options are passed to new AWS.S3() 
    // See: http://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/Config.html#constructor-property 
  },
});

module.exports = db;