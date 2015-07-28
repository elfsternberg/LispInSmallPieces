{listToString, listToVector, pairp, cons, car, cdr, caar, cddr, cdar,
 cadr, caadr, cadar, caddr, nilp, nil, setcdr, metacadr} = require "cons-lists/lists"
readline = require "readline"
{inspect} = require "util"
{Symbol} = require '../chapter1/reader_types'

class LispInterpreterError extends Error
  name: 'LispInterpreterError'
  constructor: (@message) ->

env_init = nil
env_global = env_init

definitial = (name, value = nil) ->
  env_global = (cons (cons name, value), env_global)
  name

defprimitive = (name, nativ, arity) ->
  definitial name, ((args, callback) ->
    vmargs = listToVector(args)
    if (vmargs.length == arity)
      callback nativ.apply null, vmargs
    else
      throw new LispInterpreterError "Incorrect arity")

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

# MISTAKE: Variables are always of type Symbol.  This is probably a
# mistake.

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
    if (variables instanceof Symbol)
      (cons (cons variables.v, values), env)
    else
      nil

make_function = (variables, body, env, callback) ->
  callback (values, cb) -> eprogn body, (extend env, variables, values), cb

invoke = (fn, args, callback) ->
  fn args, callback

# Takes a list of nodes and calls evaluate on each one, returning the
# last one as the value of the total expression.  In this example, we
# are hard-coding what ought to be a macro, namely the threading
# macros, "->"

eprogn = (exps, env, callback) ->
  if (pairp exps)
    if pairp (cdr exps)
      evaluate (car exps), env, (next) ->
        eprogn (cdr exps), env, callback
    else
      evaluate (car exps), env, callback
  else
    callback nil

evlis = (exps, env, callback) ->
  if (pairp exps)
    evlis (cdr exps), env, (rest) ->
      evaluate (car exps), env, (calc) ->
        callback cons calc, rest
  else
    callback nil

lookup = (id, env) ->
  if (pairp env)
    if (caar env) == id
      cdar env
    else
      lookup id, (cdr env)
  else
    nil

update = (id, env, value, callback) ->
  if (pairp env)
    if (caar env) == id
      setcdr value, (car env)
      callback value
    else
      update id, (cdr env), value, callback
  else
    callback nil

# This really ought to be the only place where the AST meets the
# interpreter core.  I can't help but think that this design precludes
#  pluggable interpreter core.

# TODO: Reengineer this with a call to normalize

astSymbolsToLispSymbols = (node) ->
  nvalu = (node) -> cadr node
  return nil if nilp node
  throw (new LispInterpreterError "Not a list of variable names") if not ((car node) is 'list')
  handler = (node) ->
    return nil if nilp node
    cons (nvalu car node).v, (handler cdr node)
  handler(nvalu node)

# Takes an AST node and evaluates it and its contents.  A node may be
# ("list" (... contents ...)) or ("number" 42) or ("symbol" x), etc.

cadddr = metacadr('cadddr')

metadata_evaluation =
  listp:     (node) -> (car node) == 'list'
  symbolp:   (node) -> (car node) == 'symbol'
  numberp:   (node) -> (car node) == 'number'
  stringp:   (node) -> (car node) == 'string'
  nvalu:     (node) -> cadr node
  mksymbols: astSymbolsToLispSymbols

straight_evaluation = 
  listp:     (node) -> node.__type == 'list'
  symbolp:   (node) -> node instanceof Symbol
  commentp:  (node) -> node instanceof Comment
  numberp:   (node) -> typeof node == 'number'
  stringp:   (node) -> typeof node == 'string'
  boolp:     (node) -> typeof node == 'boolean'
  nullp:     (node) -> node == null
  vectorp:   (node) -> (not straight_evaluation.listp node) and toString.call(node) == '[object Array]'
  recordp:   (node) -> (not node._prototype?) and toSTring.call(node) == '[object Object]'
  objectp:   (node) -> (node._prototype?) and toString.call(node) == '[object Object]'
  nilp:      (node) -> nilp(node)
  nvalu:     (node) -> node
  mksymbols: (node) -> node

makeEvaluator = (ix = straight_evaluation, ty="straight") ->
  (exp, env, callback) ->
    if ix.symbolp exp
      return callback lookup (ix.nvalu exp).v, env
    else if ([ix.numberp, ix.stringp].filter (i) -> i(exp)).length > 0
      return callback ix.nvalu exp
    else if ix.listp exp
      body = ix.nvalu exp
      head = car body
      if ix.symbolp head
        return switch (ix.nvalu head).v
          when "quote" then callback cdr body
          when "if"
            evaluate (cadr body), env, (res) ->
              w = unless res == the_false_value then caddr else cadddr
              evaluate (w body), env, callback
          when "begin" then eprogn (cdr body), env, callback
          when "set!"
            evaluate (caddr body), env, (newvalue) ->
              update (ix.nvalu cadr body).v, env, newvalue, callback
          when "lambda"
            make_function (ix.mksymbols cadr body), (cddr body), env, callback
          else
            evaluate (car body), env, (fn) ->
              evlis (cdr body), env, (args) ->
                invoke fn, args, callback
      else
        evaluate (car body), env, (fn) ->
          evlis (cdr body), env, (args) ->
            invoke fn, args, callback
    else
      throw new LispInterpreterError ("Can't handle a #{type}")

nodeEval = makeEvaluator(metadata_evaluation, "node")
lispEval = makeEvaluator(straight_evaluation, "lisp")

evaluate = (exp, env, cb) ->
  (if exp? and exp.__node then nodeEval else lispEval)(exp, env, cb)
  
module.exports = (c, cb) -> evaluate c, env_global, cb
