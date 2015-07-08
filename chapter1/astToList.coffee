{car, cdr, cons, listp, nilp, nil,
 list, pairp, listToString} = require 'cons-lists/lists'
{aSymbol, aValue, astObject} = require './astAccessors'

# RICH_AST -> LISP_AST

normalizeForm = (form) ->

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
    'symbol': id
    'number': id
    'string': (atom) -> atom
    'nil': (atom) -> nil

    # Values inherited from the VM.
    'true': (atom) -> true
    'false': (atom) -> false
    'null': (atom) -> null
    'undefined': (atom) -> undefined

  methods[(car form)](car cdr form)


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

