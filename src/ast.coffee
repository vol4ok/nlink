jsp = require("uglify-js").parser
fs = require 'fs'
{inspect} = require 'util'
console.log inspect(jsp.parse(fs.readFileSync(__dirname+'/test2.js', 'utf-8')),false, null, true)