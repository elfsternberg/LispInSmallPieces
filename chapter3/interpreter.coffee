{listToString, listToVector, pairp, cons, car, cdr, caar, cddr, cdar, cadr, caadr, cadar, caddr, nilp, nil, setcdr, metacadr} = require "cons-lists/lists"
readline = require "readline"
{inspect} = require "util"
print = require "./print"

ntype = (node) -> car node
nvalu = (node) -> cadr node

class Value

class Continuation
  constructor: (@k) ->
  invoke: (v, env, kont) ->
    if nilp cdr v
      @k.resume (car v)
    else
      throw "Continuations expect one argument", [v, env, kont]

# Abstract class representing the environment

class Environment
  lookup: -> throw "Nonspecific invocation"
  update: -> throw "Nonspecific invocation"

# Base of the environment stack.  If you hit this, your variable was
# never found for lookup/update.  Note that at this time in the
# class, you have not 

class NullEnv extends Environment
  lookup: -> throw "Unknown variable"
  update: -> throw "Unknown variable"

# This appears to be an easy and vaguely abstract handle to the
# environment.  The book is not clear on the distinction between the
# FullEnv and the VariableEnv.
            
class FullEnv extends Environment
  constructor: (@others, @name) ->
  lookup: (name, kont) ->
    @others.lookup name, kont
  update: (name, kont, value) ->
    @others.update name, kont, value

# This is the classic environment pair; either it's *this*
# environment, or it's a parent environment, until you hit the
# NullEnv.

class VariableEnv extends FullEnv
  constructor: (@others, @name, @value) ->
    lookup: (name, kont) ->
      if name == @name
        resume kont, @value
      else
        @others.lookup name, kont
    update: (nam, kont, value) ->
      if name == @name
        @value = value
        resume kont, value
      else
        @others.update name, kont, value

# QUOTE

evaluateQuote = (v, env, kont) ->
  resume kont, v

# IF    

evaluateIf = (exps, env, kont) ->
  evaluate (car e), env, new IfCont(kont, (cadr e), (caddr e), env)

class IfCont extends Continuation
  constructor: (@k, @ift, @iff, @env) ->
  resume: (v) -> evaluate (if v then @ift else @iff), @env, @k

# BEGIN

evaluateBegin = (exps, env, kont) ->
  if (pairp exps)
    if pairp (cdr exps)
      evaluate (car exps), env, (new BeginCont kont, exps, env)
    else
      evaluate (car exps), env, kont
  else
    resume kont, "Begin empty value"

class BeginCont extends Continuation
  constructor: (@k, @exps, @env) ->
  resume: (v) -> evaluateBegin (cdr @exps), @env, @k

# VARIABLE

evaluateVariable = (name, env, kont) ->
  env.lookup(name, kont)

# SET

evaluateSet = (name, exp, env, kont) ->
  evaluate exp, env, (new setCont(kont, name, env)) 

class SetCont extend Continuation
  constructor: (@k, @name, @env) ->
  resume: (value) ->
    update @env, @name, @k, value

# LAMBDA

evaluateLambda = (names, exp, env, kont) ->
  resume kont, new Function names, exp, env

class Function extends Value
  constructor: (@variables, @body, @env) ->
  invoke: (values, env, kont) ->
    evaluateBegin @body, (extend @env, @variables, values), kont

extend = (env, names, values) ->
  if (pairp names) and (pairp values)
    new VariableEnv (extend env (cdr names) (cdr values)), (car names), (car values)
  else if (nilp names)
    if (nilp values) then env else throw "Arity mismatch"
  else
    new VariableEnv env, names, values

# APPLICATION

evaluateApplication = (exp, exps, env, kont) ->
  evaluate exp, env, (new EvFunCont kont, exps, env)

class EvFunCont extends Continuation
  constructor: (@k, @exp, @env) ->
  resume: (f) ->
    evaluateArguments (@exp, @k, new ApplyCont @k, f, @env)

evaluateArguments = (exp, env, kont) ->
  if (pairp exp)
    evaluate (car exp), env, (new ArgumentCont kont, exp, env)
  else
    resume kont, "No more arguments"

class ApplyCont extends Continuation
  constructor: (@k, @fn, @env) ->
  resume: (v) ->
    invoke @fn, v, @env, @k
    
class ArgumentCont extends Continuation
  constructor: (@k, @exp, @env) ->
  resume: (v) ->
    evaluateArguments (cdr @env, @env, new GatherCont @k, v)

class GatherCont extends Continuation
  constructor: (@k, @v) ->
  resume: (v) ->
     @k.resume (cons @v, v)
    
class BottomCont extends Continuation
  constructor: (@k, @f) ->
  resume: (v) ->
    @f(v)
    
class Primitive extends Value
  constructor: (@name, @nativ) ->
  invoke: (args, env, kont) ->
    @nativ.apply null, (listToVector args), env, kont

env_init = new NullEnv()

interpreter = (ast, kont) ->
  evaluate ast, env_init, new BottomCont null, kont
  
evaluate = (e, env, kont) ->
  [type, exp] = [(ntype e), (nvalu e)]
  if type == "symbol"
    return evaluateVariable exp, env, kont
  if type in ["number", "string", "boolean", "vector"]
    return exp
  if type == "list"
    head = car exp
    if (ntype head) == 'symbol'
      switch (nvalu head)
        when "quote" then evaluateQuote (cdr exp), env, kont
        when "if" then evaluateIf (cdr exp), env, kont
        when "begin" then evaluateBegin (cdr exp), env, kont
        when "set!" then evaluateSet (nvalu cadr exp), (nvalu caddr exp), env, kont
        when "lambda" then evaluateLambda (astSymbolsToLispSymbols cadr exp), (cddr exp), env, kont
        evaluateApplication (car exp), (cdr exp), env, cont
    else
      evaluateApplication (car exp), (cdr exp), env, cont
  else
    throw new Error("Can't handle a #{type}")

definitial = (name, value = nil) ->
  env_init = new VariableEnv env_init, name, value
  name

defprimitive = (name, nativ, arity) ->
  definitial name, new Primitive name, (args, env, kont) ->
    vmargs = listToVector(args)
    if (vmargs.length == arity)
      resume kont (nativ.apply null, vmargs
    else
      throw "Incorrect arity")

defpredicate = (name, nativ, arity) ->
  defprimitive name, ((a, b) -> if nativ.call(null, a, b) then true else the_false_value), arity

the_false_value = (cons "false", "boolean")

definitial "#t", true
definitial "#f", the_false_value
definitial "nil", nil
for i in [
  "x", "y", "z", "a", "b", "c", "foo", "bar", "hux",
  "fib", "fact", "visit", "primes", "length"]
  definitial i


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

class Component
  invoke: -> throw "Not a function"

class Environment
  lookup: -> throw "Not an environment"

class NullEnv extends Environment
  lookup: -> throw "Unknown Variable"
  
class FullEnv extends Environment
  constructor: (@others, @name) ->
  lookup: (id) -> lookup id, @others

class VariableEnv extends FullEnv
  constructor:(@others, @name, @value) ->
  lookup: (id) ->

class Primitive extends Invokable
  invoke: (args, kont) -> @fn args, kont




module.exports = (c) -> evaluate c, env_global
