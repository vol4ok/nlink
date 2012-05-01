// Generated by CoffeeScript 1.3.1
(function() {
  var EMPTY_NODE, EventEmitter, Linker, fun2ast, isArray, jsp, num2ast, obj2ast, pro,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; };

  require('colors');

  jsp = require("uglify-js").parser;

  pro = require("uglify-js").uglify;

  EMPTY_NODE = ['name', ''];

  EventEmitter = require('events').EventEmitter;

  isArray = Array.isArray;

  fun2ast = function(str) {
    return (jsp.parse("a = " + str))[1][0][1][3];
  };

  num2ast = function(str) {
    return (jsp.parse(str))[1][0][1];
  };

  obj2ast = function(obj) {
    var item, key, list, value, _i, _len;
    switch (typeof obj) {
      case 'undefined':
        return ['name', 'undefined'];
      case 'string':
        return ['string', obj];
      case 'boolean':
      case 'number':
        return num2ast(obj.toString());
      case 'function':
        return fun2ast(obj.toString());
      case 'object':
        if (obj === null) {
          return ['name', 'null'];
        } else if (isArray(obj)) {
          list = [];
          for (_i = 0, _len = obj.length; _i < _len; _i++) {
            item = obj[_i];
            list.push(obj2ast(item));
          }
          return ['array', list];
        } else {
          list = [];
          for (key in obj) {
            value = obj[key];
            list.push([key, obj2ast(value)]);
          }
          return ['object', list];
        }
    }
    return EMPTY_NODE;
  };

  Linker = (function(_super) {

    __extends(Linker, _super);

    Linker.name = 'Linker';

    Linker.prototype.defaults = {
      indent: 2,
      compress: false
    };

    Linker.prototype.name = Linker.name;

    Linker.prototype.fun2ast = fun2ast;

    Linker.prototype.num2ast = num2ast;

    Linker.prototype.obj2ast = obj2ast;

    function Linker(options) {
      var _ref, _ref1;
      this.options = {
        indent: (_ref = options.indent) != null ? _ref : this.defaults.indent,
        compress: (_ref1 = options.compress) != null ? _ref1 : this.defaults.compress
      };
      jsp.set_logger(function(msg) {
        return console.log(("Parser: " + msg).yellow);
      });
      pro.set_logger(function(msg) {
        return console.log(("Process: " + msg).yellow);
      });
      this.walker = pro.ast_walker();
      this.walk = this.walker.walk;
      this.parent = this.walker.parent;
      this.stack = this.walker.stack;
      this.walkers = this.walker.with_walkers;
      this.workDir = 'test';
    }

    Linker.prototype.addListener = function(type, listener) {
      var newListener;
      newListener = function() {
        var result;
        result = listener.apply(this, arguments);
        if (result != null) {
          throw {
            result: result
          };
        }
      };
      newListener.listener = listener;
      return Linker.__super__.addListener.call(this, type, newListener);
    };

    Linker.prototype.on = Linker.prototype.addListener;

    Linker.prototype.link = function(code, options) {
      var ast, self, walk;
      walk = this.walk;
      self = this;
      ast = jsp.parse(code);
      ast = this.walker.with_walkers({
        toplevel: function(statements) {
          try {
            self.emit('toplevel', this, statements, options);
          } catch (e) {
            if (!e.result) {
              throw e;
            }
            return e.result;
          }
          return [this[0], statements.map(walk)];
        },
        call: function(expr, args) {
          try {
            self.emit('call', this, expr, args, options);
            if (expr[0] === 'name') {
              self.emit('call::name', this, expr, args, options);
            }
            if (expr[0] === 'dot') {
              self.emit('call::dot', this, expr, args, options);
              if (expr[2] === 'apply') {
                self.emit('call::apply', this, expr, args, options);
              }
              if (expr[2] === 'call') {
                self.emit('call::call', this, expr, args, options);
              }
            }
          } catch (e) {
            console.log('call catch'.red, e.result);
            if (!e.result) {
              throw e;
            }
            return e.result;
          }
          return [this[0], walk(expr), args.map(walk)];
        },
        "var": function(defs) {
          try {
            self.emit('var', this, defs, options);
          } catch (e) {
            console.log('var catch'.red, e.result);
            if (!e.result) {
              throw e;
            }
            return e.result;
          }
          return [
            this[0], defs.map(function(def) {
              var a;
              a = [def[0]];
              if (def.length > 1) {
                a[1] = walk(def[1]);
              }
              return a;
            })
          ];
        },
        name: function(name) {
          try {
            self.emit('name', this, name, options);
          } catch (e) {
            console.log('name catch'.red, e.result);
            if (!e.result) {
              throw e;
            }
            return e.result;
          }
          return this;
        }
      }, function() {
        return walk(ast);
      });
      code = pro.gen_code(ast, {
        beautify: true,
        indent_level: this.options.indent
      });
      ast = jsp.parse(code);
      if (this.options.compress) {
        ast = pro.ast_mangle(ast);
        ast = pro.ast_squeeze(ast);
        code = pro.gen_code(ast);
      } else {
        code = pro.gen_code(ast, {
          beautify: true,
          indent_level: this.options.indent
        });
      }
      return code;
    };

    return Linker;

  })(EventEmitter);

  module.exports = Linker;

  /*
    nlink -c -i -o -n -a -e ['njs'] input1 input2 input3
  */


}).call(this);