{car, cdr, cons, listp, nilp, nil,
 list, pairp, listToString} = require 'cons-lists/lists'

{Symbol, Comment} = require './reader_types'

exports.normalize = normalize = (form) ->
  return nil if nilp form

  methods =
    'vector': (form) ->
      until (nilp form) then p = normalize(car form); form = cdr form; p

    'record': (form) ->
      o = Object.create(null)
      until (nilp form)
        o[(normalize car form)] = (normalize car cdr form)
        form = cdr cdr form
        null
      o

  if (listp form) and (car form) instanceof Symbol
    if (car form).name in ['vector', 'record']
      methods[(car form).name](cdr form)
    else
      cons (normalize car form), (normalize cdr form)
  else
    form
