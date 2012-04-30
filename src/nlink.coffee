optimist = require 'optimist'
vm       = require 'vm'
fs       = require 'fs'
path     = require 'path'
Linker   = require './linker'
coffee   = require 'coffee-script'
jsp = require("uglify-js").parser
pro = require("uglify-js").uglify

EMPTY_NODE = ['name',''] #['block']

PRECOMPILE = 'PRECOMPILE'
MIXIN = 'MIXIN'
TEMPLATE = 'PRECOMPILE_TEMPLATE'
REQUIRE = 'require'
MODULE = 'module'
SUB_EXT = 'lib'
DEFINE = 'DEFINE'
IFDEF = 'IFDEF'
IFNDEF = 'IFNDEF'
MACROS = 'MACROS'

{join, dirname, basename, extname, existsSync} = path
{inspect} = require 'util'
{walkSync} = require 'fs.walker'

SANDBOX_ENV =
  fs: fs
  path: path
  __dirname: __dirname
  __filename: __filename
  
makeDir = (path, options = {}) -> 
  mode = options.mode or 0o755
  parent = dirname(path)
  makeDir(parent, options) unless existsSync(parent)
  unless existsSync(path)
    fs.mkdirSync(path, mode)
    options.createdDirs.push(path) if _.isArray(options.createdDirs)

setExt = (file, ext) -> file.replace(/(\.[^.\/]*)?$/i, ext)
removeExt = (file, ext) -> file.replace(/(\.[^.\/]*)?$/i, '')
  
readFileFromDirSync = (file, basedir, enc) ->
  old = null
  if basedir
    old = process.cwd()
    process.chdir(basedir)
  path = fs.realpathSync(file)
  result = fs.readFileSync(path, enc)
  process.chdir(old) if old
  return result

precompile = (node, expr, args, options) ->
  if expr[1] is PRECOMPILE
    code = pro.gen_code(args[0])
    obj = vm.runInNewContext("#{code}()", SANDBOX_ENV)
    ret = @obj2ast(obj)
    return ret
  return
  
macros = {}
  
macros = (node, expr, args, options) ->
  if expr[1] is MACROS and args[0][0] is 'name'
    code = pro.gen_code(args[1])
    console.log "#{args[0][1]} = #{code}".yellow
    macros[args[0][1]] = code
    console.log macros
    #obj = vm.runInNewContext("#{code}()", SANDBOX_ENV)
    #ret = @obj2ast(obj)
    #return ret
    return EMPTY_NODE
  return
  
runMacros = (node, expr, args, options) ->
   if expr[0] == 'name' and macros[expr[1]]?
     a = args.map(@walk)
     console.log '###'.green, macros[expr[1]]
     console.log '###'.green, a.map(pro.gen_code).join(',')
     console.log "(#{macros[expr[1]]})(#{a.map(pro.gen_code).join(',')})".green
     console.log (str = vm.runInNewContext("(#{macros[expr[1]]})(#{a.map(pro.gen_code).join(',')})", SANDBOX_ENV)).red
     return jsp.parse(str)
   return
  
mixin = (node, expr, args, options) ->
  if expr[1] == MIXIN
    path = vm.runInNewContext(pro.gen_code(args[0]), SANDBOX_ENV)
    code = readFileFromDirSync(path, options.outdir, 'utf-8')
    return jsp.parse(code)
  return

template = (node, expr, args, options) ->
  if expr[1] == TEMPLATE
    path = vm.runInNewContext(pro.gen_code(args[0]), SANDBOX_ENV)
    if existsSync(path)
      path = fs.realpathSync(path)
      data = fs.readFileSync(path, 'utf-8')
      switch extname(path)
        when '.mu', '.mustache'
          hogan = require 'hogan.js'
          template = hogan.compile(data, asString: yes)
          return @fun2ast(template)
        else
          return [ 'string', data ]
    else
      console.log "Error: template #{path} not found!".red
  return
  
requires = []
      
_require = (node, expr, args, options) ->
  if expr[1] == REQUIRE
    path = vm.runInNewContext(pro.gen_code(args[0]), SANDBOX_ENV)
    requires.push(path)
    parent = @parent()
    if parent[0] is 'assign' or parent[0] is 'call'
      seg = path.split('/')
      ret = ['name', seg[0]]
      for s,i in seg
        continue if i is 0
        ret = ['dot', ret, s]
      console.log 'ret'.cyan, ret
      return ret
    else
      return EMPTY_NODE
  return

moduleNames = []

module = (node, expr, args, options) ->
  if expr[1] == MODULE
    name = vm.runInNewContext(pro.gen_code(args[0]), SANDBOX_ENV)
    moduleNames.push(name)
    return EMPTY_NODE
  return

freplace = 
  '__extends' : '$.inherit'
  '__hasProp' : '$.hasProp'
  '__slice'   : '$.slice'
  '__bind'    : '$.bind'
  '__indexOf' : '$.indexOf'

replaceFunctions = (node, expr, args, options) ->
  expr[1] = freplace[expr[1]] if expr[0] == 'name' and freplace[expr[1]]?
  expr[1][1] = freplace[expr[1][1]] if expr[0] == 'dot' and 
    (expr[2] == 'call' or expr[2] == 'apply') and
    expr[1][0] == 'name' and
    freplace[expr[1][1]]?
  return

removeCoffeeScriptHelpers = (node, defs, options) ->
  newDef = []
  newDef.push def for def in defs when not /__(hasProp|extends|indexOf|slice|bind)/.test(def[0])
  walk = @walk
  return [ node[0], newDef.map (def) ->
          a = [ def[0] ]
          a[1] = walk(def[1]) if def.length > 1
          return a ]
          
defines = {}

define = (node, expr, args, options) ->
  if expr[1] is DEFINE and args[0][0] is 'name'
    defines[args[0][1]] = @walk(args[1]) ? ['name','']
    console.log 'define'.magenta, inspect(args, no, null, yes)
    return EMPTY_NODE
    
ifdef = (node, expr, args, options) ->
  if (expr[1] is IFDEF) and args[0][0] is 'name'
    #console.log '### ifdef'.green, defines[args[0][1]], @parent()
    if defines[args[0][1]]
      stats = @walk(args[1])[3]
      console.log '### ifdef'.green,stats
      if stats[stats.length-1][0] is 'return'
        stats[stats.length-1][0] = 'stat'
      return ['toplevel', stats]
    return EMPTY_NODE
    # console.log '### ifdef'.green, inspect(scope,no,null,yes), pro.gen_code(scope)
    # return scope
    #if defines[args[0][1]]
    # s = @stack()
    # list = s[s.length-3][1]
    # pos = list.indexOf(parent)
    # console.log 'scope: '.green,scope, '\n\n','list:'.green,list,'\n\n',pos
    # while scope.length > 0
    #   console.log 'scope.length:',scope.length
    #   stat = scope.pop()
    #   console.log 'stat': stat
    #   list.splice(pos,0,stat)
    #   console.log 'list.length: ',list.length
    # console.log '### ifdef'.green, list, "\n\n\n"
    #return EMPTY_NODE
# 
# ifndef = (node, expr, args, options) ->
#   if expr[1] is IFNDEF
    
replaceDefines = (node, name) ->
  console.log 'replaceDefines'.magenta, name, '->', defines[name] if defines[name]?
  return defines[name] if defines[name]?
  
_wrapNamespace = (ast, names) ->
  namesAst = []
  for name in names
    namesAst.push [ 'string', name ]
  return [ [ 'stat',
           [ 'call',
             [ 'name', '$.ns' ],
             [ [ 'array', namesAst ],
               [ 'function',
                 null,
                 [ 'exports' ], ast ] ] ] ] ]

_wrapRequireJs = (ast, modules) ->
  modAst = []
  for module in modules
    modAst.push [ 'string', module ]
  return [ [ 'stat',
           [ 'call',
             [ 'name', 'define' ],
             [ [ 'array', modAst ],
               [ 'function',
                 null,
                 [], ast ] ] ] ] ]
  
toplevel = (node, statements, options) ->
  moduleNames = [removeExt(options.path)]
  ret = statements.map(@walk)
  console.log 'toplevel'.magenta
  ret = _wrapNamespace(ret, moduleNames) unless options.bare
  #ret = _wrapRequireJs(ret, modules) if opt.wrapAmd
  return [ node[0], ret ]


argv = require('optimist')
  .usage('JS linker.\nUsage: nlink [TARGETS]')
  .options 'o',
    alias: 'outdir'
    describe: 'Output dir'
  .options 'f',
    boolean: yes
    alias: 'force'
    default: no
    describe: 'Force replace existing files'
  .options 'c',
    boolean: yes
    alias: 'compress'
    default: no
    describe: 'Compress JavaScript'
  .options 'I',
    alias: 'indent'
    default: 2
    describe: 'Set file indent'
  .options 'i'
    alias: 'include'
    describe: 'Add include dir'
  .options 'b'
    boolean: yes
    alias: 'bare'
    default: no
    describe: 'Skip wrap in namespace'
  .options 'v'
    alias: 'version'
    describe: 'Show version'
  .options 'h'
    alias: 'help'
    describe: 'Show help'
  .argv
  
if argv.h
  optimist.showHelp()
  return

if argv.v
  console.log 'nlink v0.0.1'
  return
  
console.log argv
outdir = fs.realpathSync(argv.outdir) if argv.outdir

linker = new Linker(compress: argv.compress, indent: argv.indent)
linker.on 'call::name', precompile
linker.on 'call::name', define
linker.on 'call::name', ifdef
linker.on 'call::name', template
linker.on 'call::name', mixin
linker.on 'call::name', _require
linker.on 'call::name', module
linker.on 'var', removeCoffeeScriptHelpers
linker.on 'call', replaceFunctions
linker.on 'name', replaceDefines
linker.on 'call::name', macros
linker.on 'call::name', runMacros
linker.on 'toplevel', toplevel

walkSync()
  .set(relative: '.')
  .on 'file', (path, ctx) -> 
    infile = path
    code = undefined
    console.log infile.green
    if ctx.extname() is '.coffee'
      code = fs.readFileSync(infile, 'utf-8')
      code = coffee.compile(code, bare: yes)
    if ctx.extname() is '.js'
      code = fs.readFileSync(infile, 'utf-8')
    return unless code
    console.log ctx.subpath()
    outfile = if outdir
      join(outdir, ctx.subpath(), ctx.basename(no)+'.js')
    else
      base = join(ctx.dirname(), ctx.basename(no))
      if not existsSync("#{base}.js") or argv.force then "#{base}.js" else "#{base}.#{SUB_EXT}.js"
    console.log outfile.cyan, '\n'
    code = linker.link code, 
      infile: infile
      outfile: outfile
      path: ctx.relpath()
      outdir: outdir
      bare: argv.b
    fs.writeFileSync(outfile, code, 'utf-8')
  .on 'dir', (path, ctx) ->
    console.log path.magenta
    throw 'continue' if path is outdir
  .walk(argv._)