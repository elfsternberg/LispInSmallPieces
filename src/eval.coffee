lookup = require './lookup'
{car, cdr, cadr, caadr, cdadr} = require './lists'

lispeval = (element, scope) ->

  switch (car element)
    when 'number' then parseInt (cadr element), 10
    when 'string' then (cadr element)
    when 'symbol' then lookup scope, (cadr element)
    when 'list'
      proc = lispeval (caadr element), scope
      args = cdadr element
      proc args, scope
    else throw new Error ("Unrecognized type in parse: #{(car element)}")

module.exports = lispeval

