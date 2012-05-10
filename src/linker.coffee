require 'colors'
jsp = require("uglify-js").parser
pro = require("uglify-js").uglify
{EventEmitter} = require('events')
  
EMPTY_NODE = ['name','']
isArray = Array.isArray

fun2ast = (str) ->
  return (jsp.parse("a = #{str}"))[1][0][1][3]
  
num2ast = (str) ->
  return (jsp.parse(str))[1][0][1]

obj2ast = (obj) ->
  switch typeof obj
    when 'undefined'
      return [ 'name', 'undefined' ]
    when 'string'
      return [ 'string', obj ]
    when 'boolean', 'number'
      return num2ast(obj.toString())
    when 'function'
      return fun2ast(obj.toString())
    when 'object'
      if obj is null
        return [ 'name', 'null' ]
      else if isArray(obj)
        list = []
        list.push(obj2ast(item)) for item in obj
        return [ 'array', list ]
      else
        list = []
        list.push([ key, obj2ast(value) ]) for key, value  of obj
        return [ 'object', list ]
  return EMPTY_NODE

class Linker extends EventEmitter
  defaults: 
    indent: 2
    compress: no
    
  name: @name
  
  fun2ast: fun2ast
  num2ast: num2ast
  obj2ast: obj2ast
    
  constructor: (options) ->
    @options = 
      indent   : options.indent ? @defaults.indent
      compress : options.compress ? @defaults.compress
    jsp.set_logger (msg) -> console.log "Parser: #{msg}".yellow
    pro.set_logger (msg) -> console.log "Process: #{msg}".yellow
    @walker = pro.ast_walker()
    @walk = @walker.walk
    @parent = @walker.parent
    @stack = @walker.stack
    @walkers = @walker.with_walkers
    @workDir = 'test'
    
  addListener: (type, listener) ->
    newListener = ->
      result = listener.apply(this, arguments)
      throw result: result if result?
    newListener.listener = listener
    super(type, newListener)
    
  on: @::addListener
        
  link: (code, options = {}) ->
    options = options extends @options
    walk = @walk
    self = this
    ast = jsp.parse(code)
    ast = @walker.with_walkers(
      toplevel: (statements) ->
        try
          self.emit('toplevel', this, statements, options)
        catch e
          throw e unless e.result
          return e.result
        return [ this[0], statements.map(walk) ]
      call: (expr, args) ->
        try
          self.emit('call', this, expr, args, options)
          self.emit('call::name', this, expr, args, options)  if expr[0] == 'name'
          if expr[0] == 'dot'
            self.emit('call::dot', this, expr, args, options)   
            self.emit('call::apply', this, expr, args, options) if expr[2] == 'apply'
            self.emit('call::call', this, expr, args, options)  if expr[2] == 'call'
        catch e
          throw e unless e.result
          return e.result
        return [ this[0], walk(expr), args.map(walk) ]
      var: (defs) ->
        try
          self.emit('var', this, defs, options)
        catch e
          throw e unless e.result
          return e.result
        return [ this[0], defs.map (def) ->
                a = [ def[0] ]
                a[1] = walk(def[1]) if def.length > 1
                return a ]
      name: (name) ->
        try
          self.emit('name', this, name, options)
        catch e
          throw e unless e.result
          return e.result
        return this
    , -> return walk(ast))
    code = pro.gen_code(ast, {beautify: yes, indent_level: options.indent})
    ast = jsp.parse(code)
    return ast if options.ast
    if options.compress
      ast = pro.ast_mangle(ast)
      ast = pro.ast_squeeze(ast)
      code = pro.gen_code(ast)
    else
      code = pro.gen_code(ast, {beautify: yes, indent_level: options.indent})
    return code

module.exports = Linker