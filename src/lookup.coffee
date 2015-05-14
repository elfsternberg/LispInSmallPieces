{nilp, car, cdr} = require './lists'

module.exports = lookup = (scopes, name) ->
  throw new Error "Unknown variable '#{name}'" if nilp scopes
  scope = car scopes
  return scope[name] if scope[name]?
  lookup((cdr scopes), name)

