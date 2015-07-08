var auth = {};
auth.bcrypt = require('bcrypt-nodejs');

auth.login = function (req, res) {
  var email = req.query.email;
  var password = req.query.password;
  db.pg.connect(db.conString, function(err, client, done) {
    if (err){ 
      common.send_error(res,'error fetching client from pool',err);
      return done();
    }
    async.waterfall([
      function(callback){ common.check_api_key(req,client,callback) },
      function(callback){
        client.query("SELECT authentication_token,encrypted_password FROM users WHERE email=$1;",
                     [email],function(err,result){
          if (err) return callback(err,'error running query');
          if (result.rowCount == 0) return callback(true,'bad email or password');
          var encrypted_password = result.rows[0].encrypted_password;
          var token = result.rows[0].authentication_token;
          auth.bcrypt.compare(password, encrypted_password, function(err, success) {
            if(err || !success) return callback(true,'bad email or password');
            else return res.send({"auth_token": token});
          });
        });
      }
    ],
    function(err,message){
      done();
      if(message) common.send_error(res,message,err);
    }); 
  });
};

auth.logout = function (req, res) {
  var auth_token = req.query.auth_token;
  db.pg.connect(db.conString, function(err, client, done) {
    if (err){ 
      common.send_error(res,'error fetching client from pool',err);
      return done();
    }
    async.waterfall([
      function(callback){ common.check_api_key(req,client,callback); },
      function(callback){ common.authenticate_by_token(req,client,callback); },
      function(user,callback){
        client.query("UPDATE users SET authentication_token=$1 WHERE authentication_token=$2;",
                     [common.generate_auth_token(),auth_token],function(err,result){
          if (err) return callback(err,'error running query');
          else return res.send({})
        });
      }
    ],
    function(err,message){
      done();
      if(message) common.send_error(res,message,err);
    }); 
  });
};

module.exports = auth;
