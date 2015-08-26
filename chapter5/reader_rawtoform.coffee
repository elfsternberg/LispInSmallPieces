{car, cdr, cons, listp, nilp, nil,
 list, pairp, listToString} = require 'cons-lists/lists'

{Symbol, Comment} = require './reader_types'

class Normalize
  normalize: (form) ->
    return nil if nilp form

    if (pairp form)
      if (car form) instanceof Symbol and (car form).name in ['vector', 'record']
        @[(car form).name](cdr form)
      else
        @list form
    else
      form

  list: (form) ->
    handle = (form) =>
      return nil if nilp form
      if not pairp form
        return @normalize form
      cons (@normalize car form), (handle cdr form)
    handle form

  vector: (form) ->
    until (nilp form) then p = @normalize(car form); form = cdr form; p

  record: (form) ->
    o = Object.create(null)
    until (nilp form)
      o[(@normalize car form)] = (@normalize car cdr form)
      form = cdr cdr form
      null
    o

exports.Normalize = Normalize
normalize = new Normalize()
exports.normalize = -> normalize.normalize.apply(normalize, arguments)
