optimist = require 'optimist'
nlink = require './nlink'

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
  .options 'B'
    alias: 'basedir'
    describe: 'Set base directory'
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
  process.exit(0)

if argv.v
  console.log 'nlink v'+nlink.VERSION
  process.exit(0)
  
if argv._.length is 0
  console.log 'no targets'.red
  optimist.showHelp()
  process.exit(0)
  
nlink argv._, 
  outdir: argv.outdir
  include: argv.include
  force: argv.force
  bare: argv.bare
  basedir: argv.basedir
  indent: argv.indent
  compress: argv.compress