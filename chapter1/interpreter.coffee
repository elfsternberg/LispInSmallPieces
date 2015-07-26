{listToString, listToVector, pairp, cons, car, cdr, caar, cddr,
 cdar, cadr, caadr, cadar, caddr, nilp, nil, setcdr, metacadr} = require "cons-lists/lists"
readline = require "readline"
{inspect} = require "util"
{Symbol} = require "./reader_types"

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

the_false_value = (cons "false", "boolean")

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
    if (symbolp variables)
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

astSymbolsToLispSymbols = (node) ->
  nvalu = (node) -> cadr node
  return nil if nilp node
  throw (new LispInterpreterError "Not a list of variable names") if not (ntype(node) is 'list')
  handler = (node) ->
    return nil if nilp node
    cons (nvalu car node), (handler cdr node)
  handler(nvalu node)


cadddr = metacadr('cadddr')

# This is really the only thing that changes behavior between "reader
# nodes" (nodes loaded with debugging metadata) and a standard cons
# object.  TODO: astSymbolsToLispSymbols should be deprecated in
# favor of normalizeForm (s?) and Symbol extraction

metadata_evaluation =
  listp:   (node) -> (car node) == 'list'
  symbolp: (node) -> (car node) == 'symbol'
  numberp: (node) -> (car node) == 'number'
  stringp: (node) -> (car node) == 'string'
  nvalu:   (node) -> cadr node

straight_evaluation = 
  listp:    (node) -> node.__type == 'list'
  symbolp:  (node) -> node instanceof Symbol
  commentp: (node) -> node instanceof Comment
  numberp:  (node) -> typeof node == 'number'
  stringp:  (node) -> typeof node == 'string'
  boolp:    (node) -> typeof node == 'boolean'
  nullp:    (node) -> node == null
  vectorp:  (node) -> (not straight_evaluation.listp node) and toString.call(node) == '[object Array]'
  recordp:  (node) -> (not node._prototype?) and toSTring.call(node) == '[object Object]'
  objectp:  (node) -> (node._prototype?) and toString.call(node) == '[object Object]'
  nilp:     (node) -> nilp(node)
  nvalu:    (node) -> node

makeEvaluator = (ix = straight_evaluation, ty="straight") ->
  (exp, env) ->
    console.log("Type:", ty)
    # Takes an AST node and evaluates it and its contents.  A node may be
    # ("list" (... contents ...)) or ("number" 42) or ("symbol" x), etc.
  
    if ix.symbolp(exp)
      return lookup (ix.nvalu exp).v, env
    else if ([ix.numberp, ix.stringp].filter (i) -> i(exp)).length > 0
      return exp
    else if ix.listp(exp)
      head = car ix.nvalu exp
      if ix.symbolp(head)
        switch (ix.nvalu head).v
          when "quote" then cdr exp
          when "if"
            unless (evaluate (cadr exp), env) == the_false_value
              evaluate (caddr exp), env
            else
              evaluate (cadddr exp), env
          when "begin" then eprogn (cdr exp), env
          when "set!" then update (ix.nvalu cadr exp).v, env, (evaluate (caddr exp), env)
          when "lambda" then make_function (astSymbolsToLispSymbols cadr exp), (cddr exp), env
          else invoke (evaluate (car exp), env), (evlis (cdr exp), env)
      else
        invoke (evaluate (car exp), env), (evlis (cdr exp), env)
    else
      throw new LispInterpreterError "Can't handle a #{type}"

nodeEval = makeEvaluator(metadata_evaluation, "node")
lispEval = makeEvaluator(straight_evaluation, "lisp")

evaluate = (exp, env) ->
  (if exp? and exp.__node then nodeEval else lispEval)(exp, env)

module.exports = (c) -> evaluate c, env_global
