'use strict'

var express = require('express');

var app = module.exports = express()

app.get('/', function(req, res){
  res.send('ECS Project using Jenkins and Terraform');
});

/* istanbul ignore next */
if (!module.parent) {
  app.listen(3000);
  console.log('Express started on port 3000');
}
