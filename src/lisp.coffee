fs = require 'fs'
{readForms} = require './reader'
lispeval = require './eval'
scope = require './scope'
{car, cdr, nilp, cadr} = require './lists'

module.exports =
  run: (pathname) ->
    text = fs.readFileSync(pathname, 'utf8')
    ast = readForms(text)
    (nval = (body, memo) ->
      return memo if nilp body
      nval((cdr body), lispeval((car body), scope)))(cadr ast)


    
