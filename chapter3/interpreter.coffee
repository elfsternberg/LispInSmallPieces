{listToString, listToVector, pairp, cons, car, cdr, caar, cddr, cdar, cadr, caadr, cadar, caddr, nilp, nil, setcdr, metacadr} = require "cons-lists/lists"
readline = require "readline"
{inspect} = require "util"
print = require "../chapter1/print"

env_init = nil
env_global = env_init

ntype = (node) -> car node
nvalu = (node) -> cadr node

definitial = (name, value = nil) ->
  env_global = (cons (cons name, value), env_global)
  name

defprimitive = (name, nativ, arity) ->
  definitial name, ((args, callback) ->
    vmargs = listToVector(args)
    if (vmargs.length == arity)
      callback nativ.apply null, vmargs
    else
      throw "Incorrect arity")

the_false_value = (cons "false", "boolean")

definitial "#t", true
definitial "#f", the_false_value
definitial "nil", nil
definitial "foo"
definitial "bar"
definitial "fib"
definitial "fact"

defpredicate = (name, nativ, arity) ->
  defprimitive name, ((a, b) -> if nativ.call(null, a, b) then true else the_false_value), arity

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
      throw "Too few values"
  else if (nilp variables)
    if (nilp values) then env else throw "Too many values"
  else
    if (symbolp variables)
      (cons (cons variables, values), env)
    else
      nil

make_function = (variables, body, env, callback) ->
  callback (values) -> eprogn body, (extend env, variables, values)

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

astSymbolsToLispSymbols = (node) ->
  return nil if nilp node
  throw "Not a list of variable names" if not (ntype(node) is 'list')
  handler = (node) ->
    return nil if nilp node
    cons (nvalu car node), (handler cdr node)
  handler(nvalu node)
  

# Takes an AST node and evaluates it and its contents.  A node may be
# ("list" (... contents ...)) or ("number" 42) or ("symbol" x), etc.

cadddr = metacadr('cadddr')

evaluate = (e, env, callback) ->
  [type, exp] = [(ntype e), (nvalu e)]
  if type == "symbol"
    return callback lookup exp, env
  else if type in ["number", "string", "boolean", "vector"]
    return callback exp
  else if type == "list"
    head = car exp
    if (ntype head) == 'symbol'
      return switch (nvalu head)
        when "quote"
          callback cdr exp
        when "if"
          evaluate (cadr exp), env, (res) ->
            w = unless res == the_false_value then caddr else cadddr
            evaluate (w exp), env, callback
        when "begin"
          eprogn (cdr exp), env, callback
        when "set!"
          evaluate (caddr exp), env, (newvalue) ->
            update (nvalu cadr exp), env, newvalue, callback
        when "lambda"
          make_function (astSymbolsToLispSymbols cadr exp), (cddr exp), env, callback
        else
          evaluate (car exp), env, (fn) ->
            evlis (cdr exp), env, (args) ->
              invoke fn, args, callback
    else
      evaluate (car exp), env, (fn) ->
        evlis (cdr exp), env, (args) ->
          invoke fn, args, callback
  else
    throw new Error("Can't handle a #{type}")

module.exports = (c, cb) -> evaluate c, env_global, cb
