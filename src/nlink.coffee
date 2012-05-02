vm       = require 'vm'
fs       = require 'fs'
path     = require 'path'
Linker   = require './linker'
coffee   = require 'coffee-script'
jsp = require("uglify-js").parser
pro = require("uglify-js").uglify

{join, dirname, basename, extname, existsSync, normalize, relative} = path
{inspect} = require 'util'
{walkSync} = require 'fs.walker'

EMPTY_NODE = ['name','']

PRECOMPILE = 'PRECOMPILE'
EMBED = 'EMBED'
TEMPLATE = 'PRECOMPILE_TEMPLATE'
DEFINE = 'DEFINE'
IFDEF = 'IFDEF'
IFNDEF = 'IFNDEF'
MACROS = 'MACROS'
REQUIRE = 'require'
MODULE = 'module'

SCRIPT_FILES  = ['njs', 'js', 'coffee']

SANDBOX_ENV =
  fs: fs
  path: path
  __dirname: __dirname
  __filename: __filename
  

isArray = Array.isArray
  
makeDir = (path, options = {}) -> 
  mode = options.mode or 0o755
  parent = dirname(path)
  makeDir(parent, options) unless existsSync(parent)
  unless existsSync(path)
    fs.mkdirSync(path, mode)
    options.createdDirs.push(path) if isArray(options.createdDirs)

setExt = (file, ext) -> file.replace(/(\.[^.\/]*)?$/i, ext)
removeExt = (file, ext) -> file.replace(/(\.[^.\/]*)?$/i, '')

indexIncludes = (dirs) ->
  index = {}
  add = (name, type, path, dir = no) ->
    index[name] = {name, type, path, dir}
  walkSync()
    .on 'file', (path, ctx) ->
      name = join(ctx.subpath(), ctx.basename())
      unless index[name]
        add(name, ctx.extname(no), path)
        if ctx.extname(no) in SCRIPT_FILES
          name = join(ctx.subpath(), ctx.basename(no))
          if index[name] and 
            SCRIPT_FILES.indexOf(index[name].type) > SCRIPT_FILES.indexOf(ctx.extname(no))
              index[name].type = ctx.extname(no)
              index[name].path = path 
          else
            add(name, ctx.extname(no), path)
          if ctx.basename() is 'index'
            name = ctx.subpath()
            if index[name] and 
              index[name].dir and
              SCRIPT_FILES.indexOf(index[name].type) > SCRIPT_FILES.indexOf(ctx.extname(no))
                index[name].type = ctx.extname(no)
                index[name].path = path
            else
              add(name, ctx.extname(no), path, yes)
    .walk(dirs)
  return index
  
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
    macros[args[0][1]] = code
    return EMPTY_NODE
  return
  
runMacros = (node, expr, args, options) ->
   if expr[0] == 'name' and macros[expr[1]]?
     a = args.map(@walk)
     str = vm.runInNewContext("(#{macros[expr[1]]})(#{a.map(pro.gen_code).join(',')})", SANDBOX_ENV)
     return jsp.parse(str)
   return
  
embed = (node, expr, args, options) ->
  if expr[1] == EMBED
    path = vm.runInNewContext(pro.gen_code(args[0]), SANDBOX_ENV)
    code = fs.readFileSync(options.fscope[normalize(path)].path,'utf-8')
    return jsp.parse(code)
  return

template = (node, expr, args, options) ->
  if expr[1] == TEMPLATE
    path = vm.runInNewContext(pro.gen_code(args[0]), SANDBOX_ENV)
    data = fs.readFileSync(options.fscope[normalize(path)].path,'utf-8')
    switch extname(path)
      when '.mu', '.mustache'
        hogan = require 'hogan.js'
        template = hogan.compile(data, asString: yes)
        return @fun2ast(template)
      else
        return [ 'string', data ]
  return

  
requires = []

_require = (node, expr, args, options) ->
  if expr[1] == REQUIRE
    path = vm.runInNewContext(pro.gen_code(args[0]), SANDBOX_ENV)
    requires.push(path)
    # parent = @parent()
    # seg = path.split('/')
    # ret = ['name', seg[0]]
    # for s,i in seg
    #   continue if i is 0
    #   ret = ['dot', ret, s]
    # return ret
  return


moduleNames = []

_module = (node, expr, args, options) ->
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
    return EMPTY_NODE
    
ifdef = (node, expr, args, options) ->
  if (expr[1] is IFDEF) and args[0][0] is 'name'
    if defines[args[0][1]]
      stats = @walk(args[1])[3]
      if stats[stats.length-1][0] is 'return'
        stats[stats.length-1][0] = 'stat'
      return ['toplevel', stats]
    return EMPTY_NODE
    
replaceDefines = (node, name) ->
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
  ret = _wrapNamespace(ret, moduleNames) unless options.bare
  return [ node[0], ret ]

nlink = (targets, options = {}) ->
  return unless targets
  outdir = fs.realpathSync(options.outdir) if options.outdir?
  
  linker = new Linker(compress: options.compress, indent: options.indent)
  linker.on 'call::name', precompile
  linker.on 'call::name', define
  linker.on 'call::name', ifdef
  linker.on 'call::name', template
  linker.on 'call::name', embed
  linker.on 'call::name', _require
  linker.on 'call::name', _module
  linker.on 'call::name', macros
  linker.on 'call::name', runMacros
  linker.on 'var', removeCoffeeScriptHelpers
  linker.on 'call', replaceFunctions
  linker.on 'name', replaceDefines
  linker.on 'toplevel', toplevel

  includes = []
  if options.include?
    if isArray(options.include) 
    then includes = includes.concat(options.include)
    else includes.push(options.include)
  globalScope = indexIncludes(includes)

  baseDir = options.basedir ? '.'

  count = 0

  walkSync()
    .set(relative: baseDir)
    .on 'file', (path, ctx) -> 
      infile = path
      code = undefined
      if ctx.extname() is '.coffee'
        code = fs.readFileSync(infile, 'utf-8')
        code = coffee.compile(code, bare: yes)
      if ctx.extname() is '.js'
        code = fs.readFileSync(infile, 'utf-8')
      return unless code
      outfile = if outdir
        join(outdir, ctx.subpath(), ctx.basename(no)+'.js')
      else
        base = join(ctx.dirname(), ctx.basename(no))
        if not existsSync("#{base}.js") or options.force 
        then "#{base}.js" 
        else "#{base}.njs"
      fscope = globalScope extends indexIncludes([dirname(infile)])
      makeDir(dirname(outfile))
      code = linker.link code, 
        infile: infile
        outfile: outfile
        path: ctx.relpath()
        outdir: outdir
        bare: options.bare
        fscope: fscope
      console.log "link #{ctx.relpath()} -> #{relative(baseDir, outfile)}".green
      fs.writeFileSync(outfile, code, 'utf-8')
      count++
    .on 'dir', (path, ctx) ->
      throw 'continue' if path is outdir
    .walk(targets)

  console.log "#{count} files successfully linker".cyan

nlink.VERSION = "0.0.2"
module.exports = nlink