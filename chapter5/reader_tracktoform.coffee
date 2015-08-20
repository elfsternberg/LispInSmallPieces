{car, cdr, cons, listp, nilp, nil,
 list, pairp, listToString} = require 'cons-lists/lists'

{Symbol, Comment} = require './reader_types'

exports.normalize = normalize = (form) ->
  _normalize = (form) ->
    return nil if nilp form.v
  
    methods =
      'vector': (form) ->
        until (nilp form.v) then p = normalize(car form.v); form = cdr form.v; p
  
      'record': (form) ->
        o = Object.create(null)
        until (nilp form.v)
          o[(normalize car form.v)] = (normalize car cdr form.v)
          form = cdr cdr form.v
          null
        o

      'list': (form) ->
        handle = (form) ->
          return nil if (nilp form)
          return _normalize(form) if not (listp form)
          cons (_normalize car form), (handle cdr form)
        handle(form.v)
  
    if (listp form.v)
      if (car form.v) instanceof Symbol and (car form.v).name in ['vector', 'record']
        methods[(car form.v).name](cdr form.v)
      else
        methods.list(form)
    else
      form.v

  _normalize(form)
