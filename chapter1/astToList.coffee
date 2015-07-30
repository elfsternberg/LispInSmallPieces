{car, cdr, cons, listp, nilp, nil,
 list, pairp, listToString} = require 'cons-lists/lists'
{astObject} = require './astAccessors'
{Symbol} = require './reader_types'

# RICH_AST -> LISP_AST

normalizeForm = (form) ->
  console.log(form)
  
  listToRecord1 = (l) ->
    o = Object.create(null)
    while(l != nil)
      o[normalizeForm(car l)] = normalizeForm(car cdr l)
      l = cdr cdr l
      null
    o

  listToVector1 = (l) ->
    while(l != nil) then p = normalizeForm(car l); l = cdr l; p

  id = (a) -> a

  methods =
    'list': normalizeForms
    'vector': (atom) -> listToVector1(atom)
    'record': (atom) -> listToRecord1(atom)

    # Basic native types.  Meh.
    'symbol': new Symbol(id)
    'number': id
    'string': id
    'nil': (atom) -> nil

    # Values inherited from the VM.
    'true': (atom) -> true
    'false': (atom) -> false
    'null': (atom) -> null
    'undefined': (atom) -> undefined

  methods[form.type](form.value)


normalizeForms = (forms) ->
  # Yes, this reifies the expectation than an empty list and 'nil' are
  # the same.
  return nil if nilp forms

  # Handle dotted list.
  if (astObject forms)
    return normalizeForm(forms)
  cons(normalizeForm(car forms), normalizeForms(cdr forms))

module.exports =
  normalizeForm: normalizeForm
  normalizeForms: normalizeForms

