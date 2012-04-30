module 'some-module'
module 'SomeModule'
require 'jquery'
require 'underscore'
require('callable1')(123)
require('call.able2')()
require('callable3')()


DEFINE TEST_DEFINE, 'test_define'
DEFINE __DEBUG__

IFDEF __DEBUG__, ->
  DEFINE TEST_FUN, (a) -> console.log "olololololo"
  DEFINE TEST_OBJ, {test1: TEST_DEFINE, test2: 123, f: TEST_FUN}
  a = 1
  b = a+2
  console.log '__DEBUG__',a,b  
  
# .ELSE ->
#   
#   DEFINE TEST_FUN, (a) -> console.log "olololololo"
#   DEFINE TEST_OBJ, {test1: TEST_DEFINE, test2: 123, f: TEST_FUN}

MACROS DEFINE_VAR, (val1, val2) ->
  return "var #{val1} = #{val2};\n"
  

data = PRECOMPILE_TEMPLATE 'test/tpl1.html'
Module1 = require "sm/"+"module"

DEFINE_VAR('magavar' ,"olololo")

f = () -> 
  console.log "ololo"
  setTimeout(TEST_FUN, 1000)
  send(TEST_OBJ)

MIXIN('mixin.js')
MIXIN('mixin.js')
MIXIN('mixin.js')

class ClassA
  A: PRECOMPILE -> return {test: 123, test2: "24234", test3: [1,2,3]}
  constructor: ->
    ss = TEST_DEFINE
    s = ss + TEST_DEFINE
    f(TEST_DEFINE)
    @temp = require "sm/module"
  method1: =>
    @Tmpl = PRECOMPILE_TEMPLATE "test/tpl2.mu"
  method2: =>
    @a = [1,2,3,'a']
    @method1() if 'a' in a
    
exports extends {ClassA}