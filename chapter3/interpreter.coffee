{listToString, listToVector, pairp, cons, car, cdr, caar, cddr, cdar, cadr, caadr, cadar, caddr, nilp, nil, setcdr, metacadr} = require "cons-lists/lists"
print = require "../chapter1/print"

# Debugging tool.
{inspect} = require "util"

env_init = nil
env_global = env_init

ntype = (node) -> car node
nvalu = (node) -> cadr node

# Takes a name and a value and pushes those onto the global environment.

definitial = (name, value = nil) ->
  env_global = (cons (cons name, value), env_global)
  name

# Takes a name, a native function, and the expected arity of that
# function, and returns the global environment with new a (native)
# function perpared to unpack any (interpreter) variable pairs and
# apply the (native) function with them.

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

# Wraps a native predicate in function to ensure the interpreter's
# notion of falsity is preserved.

defpredicate = (name, nativ, arity) ->
  defprimitive name, ((a, b) -> if nativ.call(null, a, b) then true else the_false_value), arity

defprimitive "cons", cons, 2
defprimitive "car", car, 2
defprimitive "set-cdr!", setcdr, 2
defprimitive "log", ((a) -> console.log a), 1
defprimitive "+", ((a, b) -> a + b), 2
defprimitive "*", ((a, b) -> a * b), 2
defprimitive "-", ((a, b) -> a - b), 2
defprimitive "/", ((a, b) -> a / b), 2
defpredicate "lt", ((a, b) -> a < b), 2
defpredicate "eq?", ((a, b) -> a == b), 2

# Takes an environment, a list of names and a list of values, and for
# each name and value pair pushes that pair onto the list, adding them
# to the environment.

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

# Takes a list of variable names, a function body, and an environment
# at the time of evaluation, and returns:
# a (native) function that takes a list of values, applies them to the
# environment, and evaluates the body, returning the resulting value.

make_function = (variables, body, env) ->
  (values) -> eprogn body, (extend env, variables, values)

# Evaluates a (native) function with of one arg with the arg provided.
# Invoke runs the functions created by make_function, and is unrelated
# to the native functions of defprimitive()

invoke = (fn, arg) -> (fn arg)

# Takes a list of nodes and calls evaluate on each one, returning the
# last one as the value of the total expression.  In this example, we
# are hard-coding what ought to be a macro, namely the threading macro
# often named "->"

eprogn = (exps, env) ->
  if (pairp exps)
    if pairp (cdr exps)
      evaluate (car exps), env
      eprogn (cdr exps), env
    else
      evaluate (car exps), env
  else
    nil

# Evaluates a list of expressions and returns a list of resolved
# values.

evlis = (exps, env) ->
  if (pairp exps)
    (cons (evaluate (car exps), env), (evlis (cdr exps), env))
  else
    nil

# Locates a named reference in the environment and returns its value.
            
lookup = (id, env) ->
  if (pairp env)
    if (caar env) == id
      cdar env
    else
      lookup id, (cdr env)
  else
    nil

# Locates a named reference in the environment and replaces its value
# with a new value.

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

astSymbolsToLispSymbols = (node) ->
  return nil if nilp node
  throw "Not a list of variable names" if not (ntype(node) is 'list')
  handler = (node) ->
    return nil if nilp node
    cons (nvalu car node), (handler cdr node)
  handler(nvalu node)
  

# Takes an AST node and evaluates it and its contents, returning the
# final value of the calculation.  A node may be ("list" (... contents
# ...)) or ("number" 42) or ("symbol" x), etc.

cadddr = metacadr('cadddr')

evaluate = (e, env) ->
  [type, exp] = [(ntype e), (nvalu e)]
  if type == "symbol"
    return lookup exp, env
  else if type in ["number", "string", "boolean", "vector"]
    return exp
  else if type == "list"
    head = car exp
    if (ntype head) == 'symbol'
      switch (nvalu head)
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
            # Note that invoke ultimately resolves to a (native)
            # function generated by make_function, and a (interpreter)
            # list that the generated (native) function knows how to
            # unpack into the actual (native) operation.
            invoke (evaluate (car exp), env), (evlis (cdr exp), env)
    else
      invoke (evaluate (car exp), env), (evlis (cdr exp), env)
  else
    throw new Error("Can't handle a #{type}")

module.exports = (c) -> evaluate c, env_global

