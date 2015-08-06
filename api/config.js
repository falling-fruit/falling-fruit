var config = {};

// Basic Configuration
config.version = '0.2';
config.port = 3100;
config.temp_dir = './temp/'+config.port;

// Postgres
config.rails_env = "development";
config.db_config_file = '../config/database.yml';

// S3
config.s3_config_file = '../config/s3.yml';
config.s3_host = 's3-us-west-2.amazonaws.com';
config.s3_thumb_size = 100;
config.s3_medium_size = 300;

// i18n
config.i18n_languages = ["es","he","pt","it","fr","de","pl"];

// Misc
config.cats = ["forager","freegan","honeybee","grafter"];

module.exports = config;
