require 'colors'
jsp = require("uglify-js").parser
pro = require("uglify-js").uglify

EMPTY_NODE = ['name',''] #['block']

{EventEmitter} = require('events')
  
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
        
  link: (code, options) ->
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
          console.log 'call catch'.red, e.result
          throw e unless e.result
          return e.result
        return [ this[0], walk(expr), args.map(walk) ]
      var: (defs) ->
        try
          self.emit('var', this, defs, options)
        catch e
          console.log 'var catch'.red, e.result
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
          console.log 'name catch'.red, e.result
          throw e unless e.result
          return e.result
        return this
    , -> return walk(ast))
    code = pro.gen_code(ast, {beautify: yes, indent_level: @options.indent})
    ast = jsp.parse(code)
    if @options.compress
      ast = pro.ast_mangle(ast)
      ast = pro.ast_squeeze(ast)
      code = pro.gen_code(ast)
    else
      code = pro.gen_code(ast, {beautify: yes, indent_level: @options.indent})
    return code

module.exports = Linker

###
  nlink -c -i -o -n -a -e ['njs'] input1 input2 input3
###
  
#   
# class Linker
#   defaults: 
#     src: []
#     dst: null
#     indent: 2
#     compress: yes
#     recursive: yes
#     wrapAmd: no
#     wrapNs: no
#     defines: {}
#     fileExts: [ 'js' ]
# 
#   constructor: (options) ->
#     jsp.set_logger (msg) -> console.log "Parser: #{msg}".yellow
#     pro.set_logger (msg) -> console.log "Process: #{msg}".yellow
#     @walker = pro.ast_walker()
#     @opt = _.defaults(options, @defaults)
#     @opt.src = [ @opt.src ] unless _.isArray(@opt.src)
#     @count = 0
#     @filter = new Filter().allow('ext', @opt.fileExts...)
#     if @opt.filter?
#       filter.allowList(@opt.filter.allow) if _.isArray(@opt.filter.allow)
#       filter.denyList(@opt.filter.deny)   if _.isArray(@opt.filter.deby)
#     for target in @opt.src 
#       
#         
#   link: (targets, outdir = null) ->
#     walkSync()
#       .on 'file', (path, ctx) => 
#         infile = path
#         return unless ctx.extname() is 'ljs'
#         outdir = ctx.dirname() unless outdir
#         outfile = join(outdir, ctx.basename(yes)+'.js')
#         makeDir(outdir)
#         @_link(infile, outfile, @opt)
#       .walk(targets)
# 
#   _link: (infile, outfile, opt) ->
#     console.log "link #{infile} -> #{outfile}".green
#     code = fs.readFileSync(infile, 'utf-8')
#     ast = jsp.parse(code)
#     walk = @walker.walk
#     modules = []
#     moduleNs = removeExt(relative(ROOT_PATH, infile)).replace('/','.')
#     self = this
#     ast = @walker.with_walkers(
#       toplevel: (statements) -> 
#         ret = statements.map(walk)
#         #console.log 'toplevel'.magenta
#         ret = self._wrapNamespace(ret, moduleNs) if opt.wrapNs
#         ret = self._wrapRequireJs(ret, modules) if opt.wrapAmd
#         return [ this[0], ret ]
#       call: (expr, args) ->
#         if expr[0] == 'name' && expr[1] == '__precompile'
#           code = pro.gen_code(args[0])
#           obj = vm.runInNewContext("#{code}()", SANDBOX_ENV)
#           ret = obj2ast(obj)
#           return ret
#         if expr[0] == 'name' && expr[1] == '__embed'
#           oldpwd = process.cwd()
#           process.chdir(dirname(infile))
#           t = path = vm.runInNewContext(pro.gen_code(args[0]), SANDBOX_ENV)
#           console.log 'embed'.magenta, path
#           if existsSync(path)
#             path = fs.realpathSync(path)
#             self.link(path, path, _.defaults(wrapNs: no, @defaults))
#             data = fs.readFileSync(path, 'utf-8')
#             embed = jsp.parse(data)
#             #console.log inspect(embed, false, null, true) if t is 'application.js'
#             process.chdir(oldpwd)
#             return embed
#           process.chdir(oldpwd)
#         if expr[0] == 'name' && expr[1] == '__template'
#           path = vm.runInNewContext(pro.gen_code(args[0]), SANDBOX_ENV)
#           if existsSync(path)
#             path = fs.realpathSync(path)
#             data = fs.readFileSync(path, 'utf-8')
#             switch extname(path)
#               when '.mu', '.mustache'
#                 template = hogan.compile(data, asString: yes)
#                 ret = jsp.parse("a = #{template}")
#                 return ret[1][0][1][3]
#               else
#                 return [ 'string', data ]
#           else
#             console.log "Error: template #{path} not found!".red
#         if expr[0] == 'name' && expr[1] == 'require'
#           path = vm.runInNewContext(pro.gen_code(args[0]), SANDBOX_ENV)
#           #console.log 'require'.cyan, path.yellow
#           modules.push(path)
#           seg = path.split('/')
#           ret = ['name', seg[0]]
#           for s,i in seg
#             continue if i is 0
#             ret = ['dot', ret, s]
#           return ret
#         if expr[0] == 'name' && expr[1] == 'include'
#           path = vm.runInNewContext(pro.gen_code(args[0]), SANDBOX_ENV)
#           modules.push(path)
#           #console.log 'include'.cyan, path.yellow
#           return [ "block" ]
# 
# 
# 
#         if expr[0] == 'name' && expr[1] == '__extends'
#           #console.log inspect(this, false, null, true)
#           expr[1] = '$.inherit'
# 
#         if expr[0] == 'name' && expr[1] == '__hasProp'
#           #console.log inspect(this, false, null, true)
#           expr[1] = '$.hasProp'
# 
#         if expr[0] == 'name' && expr[1] == '__slice'
#           #console.log inspect(this, false, null, true)
#           expr[1] = '$.slice'
# 
#         if expr[0] == 'name' && expr[1] == '__bind'
#           #console.log inspect(this, false, null, true)
#           expr[1] = '$.bind'
# 
#         if expr[0] == 'name' && expr[1] == '__indexOf'
#           #console.log inspect(this, false, null, true)
#           expr[1] = '$.indexOf'
# 
# 
#         if expr[0] == 'dot' && (expr[2] == 'call' || expr[2] == 'apply')
#           if expr[1][0] == 'name' && expr[1][1] == '__extends'
#             expr[1][1] = '$.inherit'
#           else if expr[1][0] == 'name' && expr[1][1] == '__hasProp'
#             expr[1][1] = '$.hasProp'
#           else if expr[1][0] == 'name' && expr[1][1] == '__slice'
#             expr[1][1] = '$.slice'
#           else if expr[1][0] == 'name' && expr[1][1] == '__bind'
#             expr[1][1] = '$.bind'
#           else if expr[1][0] == 'name' && expr[1][1] == '__indexOf'
#             expr[1][1] = '$.indexOf'
#           #console.log inspect(this, false, null, true)
# 
#         if expr[0] == 'name' && expr[1] == 'module'
#           moduleNs = vm.runInNewContext(pro.gen_code(args[0]), SANDBOX_ENV)
#           #console.log 'module'.cyan, moduleNs.yellow
#           opt.wrapNs = yes
#           return [ "block" ]
#         return [ this[0], walk(expr), args.map(walk) ]
#       var: (defs) ->
#         #console.log defs
#         newDef = []
#         newDef.push def for def in defs when not /__(hasProp|extends|indexOf|slice|bind)/.test(def[0])
#         #console.log newDef
#         #console.log "\n\n\n"
# 
#         return [ this[0], newDef.map (def) ->
#                 a = [ def[0] ]
#                 a[1] = walk(def[1]) if def.length > 1
#                 return a ]
#       name: (name) ->
#         if /^\__[A-Z_]+__$/.test(name) and opt.defines[name]?
#           return obj2ast(opt.defines[name])
#         return this
#     , -> return walk(ast))
# 
#     #console.log inspect(ast, false, null, true)
# 
#     code = pro.gen_code(ast, {beautify: yes, indent_level: @opt.indent})
#     if @opt.compress
#       ast = jsp.parse(code)
#       ast = pro.ast_mangle(ast)
#       ast = pro.ast_squeeze(ast)
#       code = pro.gen_code(ast)
#     fs.writeFileSync(outfile, code, 'utf-8')
# 
#   _wrapNamespace: (ast, moduleName) ->
#     return [ [ 'stat',
#              [ 'call',
#                [ 'name', '$.ns' ],
#                [ [ 'string', moduleName ],
#                  [ 'function',
#                    null,
#                    [ 'exports' ], ast ] ] ] ] ]
# 
#   _wrapRequireJs: (ast, modules) ->
#     modAst = []
#     for module in modules
#       modAst.push [ 'string', module ]
#     return [ [ 'stat',
#              [ 'call',
#                [ 'name', 'define' ],
#                [ [ 'array', modAst ],
#                  [ 'function',
#                    null,
#                    [], ast ] ] ] ] ]