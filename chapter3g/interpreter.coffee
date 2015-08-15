{listToString, listToVector, pairp, cons, car, cdr, caar, cddr, cdar,
 cadr, caadr, cadar, caddr, nilp, nil, setcdr,
 metacadr, setcar} = require "cons-lists/lists"
{normalizeForms, normalizeForm} = require "../chapter1/astToList"
{Node, Symbol} = require '../chapter1/reader_types'

class LispInterpreterError extends Error
  name: 'LispInterpreterError'
  constructor: (@message) ->

the_false_value = (cons "false", "boolean")

# An equality function that compares two values.  This is necessary
# because object comparison in Javascipt is by reference, not by value.
# I want them to be by value, and this accomplishes that in this one
# special case.

eq = (id1, id2) ->
  if id1 instanceof Symbol and id2 instanceof Symbol
    return id1.name == id2.name
  id1 == id2

# Base class that represents a value.  Base class representing a LiSP
# value, a primitive, or a function

class Value

# Represents the base class of a continuation.  

class Continuation
  # Takes an existing continuation, which represents what to do when
  # this continuation is invoked.
  constructor: (@kont) ->

  # Near as I can tell, this exists strictly to support call/cc
  invoke: (value, env, kont) ->
    if nilp cdr value
      @kont.resume (car value)
    else
      throw new LispInterpreterError "Continuations expect one argument"

  # As we're unwinding the stack, when we receive a new ktarget we've
  # "breached" where this protection was created and need to resume the
  # continuation passed there.
  unwind: (value, ktarget) ->
    if (@ == ktarget) then (@kont.resume value) else (@kont.unwind value, ktarget)

  # When a throw happens, we need to proceed down the stack looking
  # for a CatchContinuation.  This supports that for all continuations.
  catchLookup: (tag, kk) ->
    @kont.catchLookup tag, kk

  # Resume is literally the "What to do next."  
  resume: (value) ->
    throw new LispInterpreterError "Wrong continuation for #{@_type}"

# Abstract class representing the environment

class Environment
  lookup: -> throw new LispInterpreterError "Nonspecific invocation"
  update: -> throw new LispInterpreterError "Nonspecific invocation"
  blockLookup: -> throw new LispInterpreterError "Not an Environment"

# Base of the environment stack.  If you hit this, your variable was
# never found for lookup/update.  Note that at this time in the
# class, you have not

class NullEnv extends Environment
  lookup: (e) -> throw new LispInterpreterError "Unknown variable #{e}"
  update: (e) -> throw new LispInterpreterError "Unknown variable #{e}"
  blockLookup: (name) -> throw new LispInterpreterError "Unknown block label #{name}"

# This appears to be an easy and vaguely abstract handle to the
# environment.  The book is not clear on the distinction between the
# FullEnv and the VariableEnv.

class FullEnv extends Environment
  constructor: (@others, @name) ->
    @_type = "FullEnv"
  lookup: (name, kont) ->
    @others.lookup name, kont
  update: (name, kont, value) ->
    @others.update name, kont, value
  blockLookup: (name, kont, value) ->
    @others.blockLookup(name, kont, value)

# This is the classic environment pair; either it's *this*
# environment, or it's a parent environment, until you hit the
# NullEnv.  Once the name has been found, the continuation is called
# with the found value.

class VariableEnv extends FullEnv
  constructor: (@others, @name, @value) ->
    @_type = "VariableEnv"
  lookup: (name, kont) ->
    if name == @name
      kont.resume @value
    else
      @others.lookup name, kont
  update: (name, kont, value) ->
    if name == @name
      @value = value
      kont.resume value
    else
      @others.update name, kont, value

# "Renders the quote term to the current continuation"; in a more
# familiar parlance, calls resume in the current context with the
# quoted term uninterpreted.

evaluateQuote = (v, env, kont) ->
  kont.resume normalizeForms v

# Evaluates the conditional expression, creating a continuation with
# the current environment that, when resumed, evaluates either the
# true or false branch, again in the current enviornment.

evaluateIf = (exps, env, kont) ->
  evaluate (car exps), env, new IfCont(kont, (cadr exps), (caddr exps), env)

class IfCont extends Continuation
  constructor: (@kont, @ift, @iff, @env) ->
    @_type = "IfCont"
  resume: (value) ->
    evaluate (if value == the_false_value then @iff else @ift), @env, @kont

# Sequences: evaluates the current expression with a continuation that
# represents "the next expression" in the sequence.  Upon resumption,
# calls this function with that next expression.  You can begin to
# note how the "what to do next" gets wrapped in deeper and deeper
# layers of context until the current needs are resolved and we
# finally reach that final expression.

evaluateBegin = (exps, env, kont) ->
  if (pairp exps)
    if pairp (cdr exps)
      evaluate (car exps), env, (new BeginCont kont, exps, env)
    else
      evaluate (car exps), env, kont
  else
    kont.resume("Begin empty value")

class BeginCont extends Continuation
  constructor: (@kont, @exps, @env) ->
    @_type = "BeginCont"
  resume: (v) -> evaluateBegin (cdr @exps), @env, @kont

# In this continuation, we simply pass the continuation and the name
# to the environment to look up.  The environment knows to call the
# continuation with the value.

evaluateVariable = (name, env, kont) ->
  env.lookup(name, kont)

# This is the same dance as lookup, only with the continuation being
# called after an update has been performed.

evaluateSet = (name, exp, env, kont) ->
  evaluate exp, env, (new SetCont(kont, name, env))

class SetCont extends Continuation
  constructor: (@kont, @name, @env) ->
    @_type = "SetCont"
  resume: (value) ->
    @env.update @name, @kont, value

# Calls the current contunation, passing it a new function wrapper.

evaluateLambda = (names, exp, env, kont) ->
  kont.resume new Function names, exp, env

# Upon invocation, evaluates the body with a new environment that
# consists of the original names, their current values as called, and
# the continuation an the moment of invocation, which will continue
# (resume) execution once the function is finished.
#
# By the way: this is pretty much the whole the point.

class Function extends Value
  constructor: (@variables, @body, @env) ->
    @_type = "Function"
  invoke: (values, env, kont) ->
    evaluateBegin @body, (extend @env, @variables, values), kont

# Helper function to build name/value pairs for the current execution
# context.

extend = (env, names, values) ->
  if (pairp names) and (pairp values)
    new VariableEnv (extend env, (cdr names), (cdr values)), (car names), (car values)
  else if (nilp names)
    if (nilp values) then env else throw new LispInterpreterError "Arity mismatch"
  else
    new VariableEnv env, names, values

# Now we start the invocation: this is applying the function.  Let's
# take it stepwise.

# Evaluate the application of a function call.  The first step is to
# evaluate the first element of the function call, assuming it is or
# will resolve to a function (something of type * -> *).  The
# continuation we create is to evaluate-function-cont.

evaluateApplication = (exp, exps, env, kont) ->
  evaluate exp, env, (new EvFunCont kont, exps, env)

# After the function reference is finally generated, the resume()
# function here takes that reference and creates an
# apply-continuation, then calls evaluateArguments.  See that.

class EvFunCont extends Continuation
  constructor: (@kont, @exp, @env) ->
    @_type = "EvFunCont"
  resume: (f) ->
    evaluateArguments @exp, @env, (new ApplyCont(@kont, f, @env))

# Evaluate the argument list, creating a new list of the arguments.
# For each argument pair, in calls the gather-cont, which creates the
# actual pair and resumes by processing the next pair, building the
# new environment.  When the list is exhausted, the EvFunCont's built
# ApplyCont() is called with the generated new environment and its
# associated thunk.

evaluateArguments = (exp, env, kont) ->
  if (pairp exp)
    evaluate (car exp), env, (new ArgumentCont kont, exp, env)
  else
    kont.resume(nil)

class ArgumentCont extends Continuation
  constructor: (@kont, @exp, @env) ->
    @_type = "ArgumentCont"
  resume: (v) ->
    evaluateArguments (cdr @exp), @env, (new GatherCont @kont, v)

# Gather the arguments as each ArgumentCont is resumed into a list to
# be passed to our next step.

class GatherCont extends Continuation
  constructor: (@kont, @value) ->
    @_type = "GatherCont"
  resume: (value) ->
    @kont.resume (cons @value, value)

# Called with the new environment, and the orginal continuation that
# says what to do with the value generated by this function, now that
# it's actually been invoke.

class ApplyCont extends Continuation
  constructor: (@kont, @fn, @env) ->
    @_type = "ApplyCont"
  resume: (value) ->
    @fn.invoke value, @env, @kont

# A special continuation that represents what we want the interpreter
# to do when it's done processing.

class BottomCont extends Continuation
  constructor: (@kont, @func) ->
    @_type = "BottomCont"
  resume: (value) ->
    @func(value)
  unwind: (value, ktarget) ->
    throw new LispInterpreterError "Obsolete continuation"
  catchLookup: (tag, kk) ->
    throw new LispInterpreterError "No associated catch"

# A block is an implicit begin.  So we evaluate it's contents with a
# new block-environment, which will automatically unwind any contents
# found within by traversing up the environment stack looking for
# labels that match the one with which this block was created.

evaluateBlock = (label, body, env, kont) ->
  k = new BlockCont(kont, label)
  evaluateBegin body, (new BlockEnv env, label, k), k

class BlockCont extends Continuation
  constructor: (@kont, @label) ->
    @_type = "BlockCont"
  resume: (value) ->
    @kont.resume value

class BlockEnv extends FullEnv
  constructor: (@others, @name, @kont) ->
  blockLookup: (name, kont, value) ->
    if (name == @name)
      kont.unwind value, @kont
    else
      @others.blockLookup(name, kont, value)

evaluateReturnFrom = (label, form, env, kont) ->
  evaluate form, env, (new ReturnFromCont kont, env, label)

# Note that when return-from-cont's body has been evaluated, we then
# unwind up the environment stack until we find the first block that
# has the same label and call the continuation saved there.  Note that
# this is the *first* time that continuation and executable is stored
# on the environment, and isn't implicitly part of the continuation
# stack.

class ReturnFromCont extends Continuation
  constructor: (@kont, @env, @label) ->
    @_type = "ReturnFromCont"
  resume: (v) ->
    @env.blockLookup @label, @kont, v

evaluateCatch = (tag, body, env, kont) ->
  evaluate tag, env, (new CatchCont kont, body, env)

# catch-continuation receives (from evaluate) the processed value of a
# tag, the current environment, and what should happen after the
# context containing the catch is complete (the passed in 'kont' to
# evaluateCatch).  That processed value becomes the label of the new
# labeled-continuation.

class CatchCont extends Continuation
  constructor: (@kont, @body, @env) ->
    @_type = "CatchFromCont"
  resume: (value) ->
    evaluateBegin @body, @env, (new LabeledCont @kont, value)

# Resume here does just that; it just resumes with the continuation
# passed in above.  But should catch be *triggered* by a throw (and
# the throw-continuation), we get the contents of throw as an object
# to be evaluated with its current environment, then continue with
# *this* as the continuation passed to throwing-continuation, which
# resumes the catchLookup until the stack is exhausted.

class LabeledCont extends Continuation
  constructor: (@kont, @tag) ->
    @_type = "LabeledFromCont"
  resume: (value) ->
    @kont.resume value
  catchLookup: (tag, kk) ->
    if eq tag, @tag
      evaluate kk.form, kk.env, (new ThrowingCont kk, tag, this)
    else
      @kont.catchLookup tag, kk

class ThrowCont extends Continuation
  constructor: (@kont, @form, @env) ->
    @_type = "ThrowCont"
  resume: (value) ->
    @catchLookup value, @
  
evaluateThrow = (tag, form, env, kont) ->
  evaluate tag, env, (new ThrowCont kont, form, env)

class UnwindCont extends Continuation
  constructor: (@kont, @value, @target) ->
  resume: (value) ->
    @kont.unwind @value, @target

evaluateUnwindProtect = (form, cleanup, env, kont) ->
  evaluate form, env, (new UnwindProtectCont kont, cleanup, env)

# If the continuation is "resumed," it works like normal; but if its
# "unwound," it works its way up the unwind stack looking for the
# target continuation to which to deliver the value.

class UnwindProtectCont extends Continuation
  constructor: (@kont, @cleanup, @env) ->
    @_type = "UnwindProtectCont"
  resume: (value) ->
    evaluateBegin @cleanup, @env, (new ProtectReturnCont @kont, value)
  unwind: (value, target) ->
    evaluateBegin @cleanup, @env, (new UnwindCont @kont, value, target)

# Works its way through the stack environment stack, looking for
# ("breaching") protected blocks to unwind, and processing them as
# necessary.  One of those will by definition be the continuation
# passed to the catch continuation: the throwing-continuation was
# constructed with the catch continuation itself as the address of the
# resumecont.

class ThrowingCont extends Continuation
  constructor: (@kont, @tag, @resumecont) ->
    @_type = "ThrowingCont"
  resume: (value) ->
    @kont.unwind value, @resumecont

# Note that this behavior basically much like throwing-continuation,
# except that it's the resumption (the next continuation), rather than
# the rewind.

class ProtectReturnCont extends Continuation
  constructor: (@kont, @value) ->
    @_type = "ProtectReturnCont"
  resume: (value) ->
    @kont.resume @value

# The bottom of the function pile, where native code is invoked.

class Primitive extends Value
  constructor: (@name, @nativ) ->
    @_type = "Primitive"
  invoke: (args, env, kont) ->
    @nativ.apply null, [args, env, kont]

env_init = new NullEnv()

definitial = (name, value = nil) ->
  env_init = new VariableEnv env_init, name, value
  name

defprimitive = (name, nativ, arity) ->
  definitial name, new Primitive name, (args, env, kont) ->
    vmargs = listToVector(args)
    if (vmargs.length == arity)
      # Note that native.apply(ctx, vmargs) is expected to return a
      # singleton, like all evaluate() passes.
      kont.resume (nativ.apply null, vmargs)
    else 
      throw new LispInterpreterError "Incorrect arity"

defpredicate = (name, nativ, arity) ->
  defprimitive name, ((a, b) -> if nativ.call(null, a, b) then true else the_false_value), arity

definitial "#t", true
definitial "#f", the_false_value
definitial "nil", nil

# FIXME: All of these things dereference to the same value!!!!

for i in [
  "x", "y", "z", "a", "b", "c", "foo", "bar", "hux",
  "fib", "fact", "visit", "primes", "length"]
  definitial i

defprimitive "cons", cons, 2
defprimitive "car", car, 2
defprimitive "cdr", cdr, 2
defprimitive "set-cdr!", setcdr, 2
defprimitive "set-car!", setcar, 2
defprimitive "+", ((a, b) -> a + b), 2
defprimitive "*", ((a, b) -> a * b), 2
defprimitive "-", ((a, b) -> a - b), 2
defprimitive "/", ((a, b) -> a / b), 2
defpredicate "lt", ((a, b) -> a < b), 2
defpredicate "gt", ((a, b) -> a > b), 2
defpredicate "lte", ((a, b) -> a <= b), 2
defpredicate "gte", ((a, b) -> a >= b), 2
defpredicate "eq?", ((a, b) -> a == b), 2
defpredicate "pair?", ((a) -> pairp a), 1
defpredicate "nil?", ((a) -> nilp a), 1
defpredicate "symbol?", ((a) -> /\-?[0-9]+$/.test(a) == false), 1

definitial "call/cc", new Primitive "call/cc", (values, env, kont) ->
  if nilp cdr values
    (car values).invoke (cons kont), env, kont
  else
    throw new LispInterpreterError "Incorrect arity for call/cc"

definitial "apply", new Primitive "apply", (values, env, kont) ->
  if pairp cdr values
    f = car values
    args = (() ->
      (flat = (args) ->
        if nilp (cdr args) then (car args) else (cons (car args), (flat cdr args)))(cdr values))()
    f.invoke args, env, kont

definitial "funcall", new Primitive "funcall", (args, env, kont) ->
    if not nilp cdr args
      kont.invoke (env.lookup (car args)), (cdr args)
    else
      throw new LispInterpreterError "Invoke requires a function name and arguments"

definitial "list", new Primitive "list", (values, env, kont) ->
  (values, env, kont) -> kont.resume(values)

# Only called in rich node mode...

astSymbolsToLispSymbols = (node) ->
  return nil if nilp node
  throw (new LispInterpreterError "Not a list of variable names") if not node.type == 'list'
  handler = (cell) ->
    return nil if nilp cell
    cons (car cell).value, (handler cdr cell)
  handler node.value

metadata_evaluation =
  listp:     (node) -> node.type == 'list'
  symbolp:   (node) -> node.type == 'symbol'
  numberp:   (node) -> node.type == 'number'
  stringp:   (node) -> node.type == 'string'
  commentp:  (node) -> node.type == 'comment'
  nvalu:     (node) -> node.value
  mksymbols: (list) -> astSymbolsToLispSymbols(list)

# The hairness of this makes me doubt the wisdom of using Javascript.

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


prox = 
  "quote":   (body, env, kont, ix) -> evaluateQuote (cadr body), env, kont
  "if":      (body, env, kont, ix) -> evaluateIf (cdr body), env, kont
  "begin":   (body, env, kont, ix) -> evaluateBegin (cdr body), env, kont
  "set!":    (body, env, kont, ix) -> evaluateSet (ix.nvalu cadr body), (caddr body), env, kont
  "lambda":  (body, env, kont, ix) -> evaluateLambda (ix.mksymbols cadr body), (cddr body), env, kont
  "block":   (body, env, kont, ix) -> evaluateBlock (ix.nvalu cadr body), (cddr body), env, kont
  "return":  (body, env, kont, ix) -> evaluateReturnFrom (ix.nvalu cadr body), (caddr body), env, kont
  "catch":   (body, env, kont, ix) -> evaluateCatch (cadr body), (cddr body), env, kont
  "throw":   (body, env, kont, ix) -> evaluateThrow (cadr body), (caddr body), env, kont
  "protect": (body, env, kont, ix) -> evaluateUnwindProtect (cadr body), (cddr body), env, kont

makeEvaluator = (ix = straight_evaluation, ty="straight") ->
  (exp, env, kont) ->
    if ix.symbolp exp
      return evaluateVariable (ix.nvalu exp), env, kont
    else if ([ix.numberp, ix.stringp].filter (i) -> i(exp)).length > 0
      return kont.resume ix.nvalu exp
    else if ix.listp exp
      body = ix.nvalu exp
      head = car body
      if ix.symbolp head
        # Every call is boiled down to body/env/kont (with ix.nvalu tossed in for fun)
        # It should be possible to move natives into an address space
        if prox[(ix.nvalu head)]?
          prox[(ix.nvalu head)](body, env, kont, ix)
        else evaluateApplication (car body), (cdr body), env, kont
      else
        evaluateApplication (car body), (cdr body), env, kont
    else
      throw new LispInterpreterError("Can't handle a '#{type}'")
  
nodeEval = makeEvaluator(metadata_evaluation, "node")
lispEval = makeEvaluator(straight_evaluation, "lisp")

evaluate = (exp, env, kont) ->
  (if exp? and (exp instanceof Node) then nodeEval else lispEval)(exp, env, kont)

interpreter = (ast, kont) ->
  evaluate ast, env_init, new BottomCont null, kont

module.exports = interpreter
