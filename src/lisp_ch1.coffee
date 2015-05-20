{listToString, listToVector, pairp, cons, car, cdr, caar, cddr, cdar, cadr, caadr, cadar, caddr, nilp, nil, setcdr, metacadr} = require "cons-lists/lists"
readline = require "readline"
{inspect} = require "util"

env_init = nil
env_global = env_init

ntype = (node) -> car node
nvalu = (node) -> cadr node

definitial = (name, value = nil) ->
  env_global = (cons (cons name, value), env_global)
  name

defprimitive = (name, nativ, arity) ->
  definitial name, ((args) ->
    vmargs = listToVector(args)
    if (vmargs.length == arity)
      nativ.apply null, vmargs
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

make_function = (variables, body, env) ->
  (values) -> eprogn body, (extend env, variables, values)

invoke = (fn, args) ->
  fn(args)

# Takes a list of nodes and calls evaluate on each one, returning the
# last one as the value of the total expression.  In this example, we
# are hard-coding what ought to be a macro, namely the threading
# macros, "->"

eprogn = (exps, env) ->
  if (pairp exps)
    if pairp (cdr exps)
      evaluate (car exps), env
      return eprogn (cdr exps), env
    return evaluate (car exps), env
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

# This really ought to be the only place where the AST meets the
# interpreter core.  I can't help but think that this design precludes
#  pluggable interpreter core.

cadddr = metacadr("cadddr")

astSymbolsToLispSymbols = (node) ->
  return nil if nilp node
  throw "Not a list of variable names" if not (ntype(node) is 'list')
  handler = (node) ->
    return nil if nilp node
    cons (nvalu car node), (handler cdr node)
  handler(nvalu node)
  

# Takes an AST node and evaluates it and its contents.  A node may be
# ("list" (... contents ...)) or ("number" 42) or ("symbol" x), etc.

evaluate = (e, env) ->
  [type, exp] = [(ntype e), (nvalu e)]
  if type == "symbol"
    return lookup exp, env
  if type in ["number", "string", "boolean", "vector"]
    return exp
  if type == "list"
    head = car exp
    if (ntype head) == 'symbol'
      return switch (nvalu head)
        when "quote" then cdr exp
        when "if"
          unless (evaluate (cadr exp), env) == the_false_value
            evaluate (caddr exp), env
          else
            evaluate (cadddr exp), env
        when "begin" then eprogn (cdr exp), env
        when "set!" then update (nvalu cadr exp), env, (evaluate (caddr exp), env)
        when "lambda" then make_function (astSymbolsToLispSymbols cadr exp), (cddr exp), env
        else
          invoke (evaluate (car exp), env), (evlis (cdr exp), env)
      return invoke (evaluate (car exp), env), (evlis (cdr exp), env)
  throw new Error("Can't handle a #{type}")

module.exports = (c) -> evaluate c, env_global
