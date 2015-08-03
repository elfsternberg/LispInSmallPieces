{listToString, listToVector, pairp, cons, car, cdr, caar, cddr,
 cdar, cadr, caadr, cadar, caddr, nilp, nil, setcdr, metacadr} = require "cons-lists/lists"
{Node} = require "./reader_types"

class LispInterpreterError extends Error
  name: 'LispInterpreterError'
  constructor: (@message, position = null) ->

env_init = nil
env_global = env_init

definitial = (name, value = nil) ->
  env_global = (cons (cons name, value), env_global)
  name

defprimitive = (name, nativ, arity) ->
  definitial name, ((args) ->
    vmargs = listToVector(args)
    if (vmargs.length == arity)
      nativ.apply null, vmargs
    else
      throw (new LispInterpreterError "Incorrect arity"))

defpredicate = (name, nativ, arity) ->
  defprimitive name, ((a, b) -> if nativ.call(null, a, b) then true else the_false_value), arity

the_false_value = (cons "false", "boolean")

definitial "#t", true
definitial "#f", the_false_value
definitial "nil", nil
definitial "foo"
definitial "bar"
definitial "fib"
definitial "fact"

defprimitive "cons", cons, 2
defprimitive "car", car, 2
defprimitive "set-cdr!", setcdr, 2
defprimitive "+", ((a, b) -> a + b), 2
defprimitive "*", ((a, b) -> a * b), 2
defprimitive "-", ((a, b) -> a - b), 2
defprimitive "/", ((a, b) -> a / b), 2
defpredicate "lt", ((a, b) -> a < b), 2
defpredicate "eq?", ((a, b) -> a == b), 2

extend = (env, variables, values) ->
  if (pairp variables)
    if (pairp values)
      (cons (cons (car variables), (car values)),
        (extend env, (cdr variables), (cdr values)))
    else
      throw new LispInterpreterError "Too few values"
  else if (nilp variables)
    if (nilp values) then env else throw new LispInterpreterError "Too many values"
  else
    if (variables.type == 'symbol')
      (cons (cons variables, values), env)
    else
      nil

make_function = (variables, body, env) ->
  (values) -> eprogn body, (extend env, variables, values)

invoke = (fn, args) ->
  (fn args)

# Takes a list of nodes and calls evaluate on each one, returning the
# last one as the value of the total expression.  In this example, we
# are hard-coding what ought to be a macro, namely the threading
# macros, "->"

eprogn = (exps, env) ->
  if (pairp exps)
    if pairp (cdr exps)
      evaluate (car exps), env
      eprogn (cdr exps), env
    else
      evaluate (car exps), env
  else
    nil

evlis = (exps, env) ->
  if (pairp exps)
    (cons (evaluate (car exps), env), (evlis (cdr exps), env))
  else
    nil
    
lookup = (id, env) ->
  if (pairp env)
    if (caar env) == id
      cdar env
    else
      lookup id, (cdr env)
  else
    nil

update = (id, env, value) ->
  if (pairp env)
    if (caar env) == id
      setcdr value, (car env)
      value
    else
      update id, (cdr env), value
  else
    nil

# TODO: Reengineer this with a call to normalize

tap = (i) -> console.log(i) ; i

astSymbolsToLispSymbols = (node) ->
  return nil if nilp node
  throw (new LispInterpreterError "Not a list of variable names") if not node.type == 'list'
  handler = (cell) ->
    return nil if nilp cell
    cons (car cell).value, (handler cdr cell)
  handler node.value

cadddr = metacadr('cadddr')

# This is really the only thing that changes behavior between "reader
# nodes" (nodes loaded with debugging metadata) and a standard cons
# object.  TODO: astSymbolsToLispSymbols should be deprecated in
# favor of normalizeForm (s?) and Symbol extraction

metadata_evaluation =
  listp:     (node) -> node.type == 'list'
  symbolp:   (node) -> node.type == 'symbol'
  numberp:   (node) -> node.type == 'number'
  stringp:   (node) -> node.type == 'string'
  commentp:  (node) -> node.type == 'comment'
  nvalu:     (node) -> node.value
  mksymbols: (list) -> astSymbolsToLispSymbols(list)

straight_evaluation =
  listp:     (cell) -> cell.__type == 'list'
  symbolp:   (cell) -> typeof cell == 'string' and cell.length > 0 and cell[0] not in ["\"", ";"]
  commentp:  (cell) -> typeof cell == 'string' and cell.length > 0 and cell[0] == ";"
  numberp:   (cell) -> typeof cell == 'number'
  stringp:   (cell) -> typeof cell == 'string' and cell.length > 0 and cell[0] == "\""
  boolp:     (cell) -> typeof cell == 'boolean'
  nullp:     (cell) -> cell == null
  vectorp:   (cell) -> (not straight_evaluation.listp cell) and toString.call(cell) == '[object Array]'
  recordp:   (cell) -> (not cell._prototype?) and toSTring.call(cell) == '[object Object]'
  objectp:   (cell) -> (cell._prototype?) and toString.call(cell) == '[object Object]'
  nilp:      (cell) -> nilp(cell)
  nvalu:     (cell) -> cell
  mksymbols: (cell) -> cell

makeEvaluator = (ix = straight_evaluation, ty="straight") ->
  (exp, env) ->
    # Takes an AST node and evaluates it and its contents.  A node may be
    # ("list" (... contents ...)) or ("number" 42) or ("symbol" x), etc.
    if ix.symbolp(exp)
      return lookup (ix.nvalu exp), env
    else if ([ix.numberp, ix.stringp].filter (i) -> i(exp)).length > 0
      return ix.nvalu exp
    else if ix.listp(exp)
      body = ix.nvalu exp
      head = car body
      if ix.symbolp(head)
        switch (ix.nvalu head)
          when "quote" then cdr body
          when "if"
            unless (evaluate (cadr body), env) == the_false_value
              evaluate (caddr body), env
            else
              evaluate (cadddr body), env
          when "begin" then eprogn (cdr body), env
          when "set!" then update (ix.nvalu cadr body), env, (evaluate (caddr body), env)
          when "lambda" then make_function (ix.mksymbols cadr body), (cddr body), env
          else invoke (evaluate (car body), env), (evlis (cdr body), env)
      else
        invoke (evaluate (car body), env), (evlis (cdr body), env)
    else
      throw new LispInterpreterError "Can't handle a #{exp.type}"

nodeEval = makeEvaluator(metadata_evaluation, "node")
lispEval = makeEvaluator(straight_evaluation, "lisp")

evaluate = (exp, env) ->
  (if exp? and (exp instanceof Node) then nodeEval else lispEval)(exp, env)

module.exports = (c) -> evaluate c, env_global
