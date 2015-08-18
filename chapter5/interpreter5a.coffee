{listToString, listToVector, pairp, cons, car, cdr, caar, cddr, cdar,
 cadr, caadr, cadar, caddr, nilp, nil, setcdr,
 metacadr, setcar} = require "cons-lists/lists"
{length} = require "cons-lists/reduce"
{normalizeForms, normalizeForm} = require "../chapter1/astToList"
{Node, Comment, Symbol} = require '../chapter1/reader_types'
{inspect} = require 'util'

itap = (a) -> return inspect a, true, null, false

class LispInterpreterError extends Error
  name: 'LispInterpreterError'
  constructor: (@message) ->

the_false_value = (cons "false", "boolean")

eq = (id1, id2) ->
  if id1 instanceof Symbol and id2 instanceof Symbol
    return id1.name == id2.name
  id1 == id2

# Only called in rich node mode...

astSymbolsToLispSymbols = (node) ->
  return nil if nilp node
  throw (new LispInterpreterError "Not a list of variable names") if not node.type == 'list'
  handler = (cell) ->
    return nil if nilp cell
    cons (car cell).value, (handler cdr cell)
  handler node.value

cadddr = metacadr('cadddr')

intlistp =     (node) -> node.type == 'list'
intpairp =     (node) -> node.type == 'list' and ((node.value.length < 2) or node.value[1].node.type != 'list')
intsymbolp =   (node) -> node.type == 'symbol' or node instanceof Symbol
intnumberp =   (node) -> node.type == 'number'
intstringp =   (node) -> node.type == 'string'
intcommentp =  (node) -> node.type == 'comment'
intnvalu =     (node) -> node.value
intatomp =     (node) -> node.type in ['symbol', 'number', 'string']
intnullp =     (node) -> node.type == 'symbol' and node.value.name == 'null'
intmksymbols = (list) -> astSymbolsToLispSymbols(list)

# The hairness of this makes me doubt the wisdom of using Javascript.

sBehavior = new Symbol 'behavior'
sBoolean  = new Symbol 'boolean'
sBoolify  = new Symbol 'boolify'
sFunction = new Symbol 'function'
sSymbol   = new Symbol 'symbol'
sString   = new Symbol 'string'
sValue    = new Symbol 'chars'
sName     = new Symbol 'name'
sNumber   = new Symbol 'number'
sNull     = new Symbol 'null'
sTag      = new Symbol 'tag'
sType     = new Symbol 'type'
sValue    = new Symbol 'value'
sPair     = new Symbol 'pair'
sCar      = new Symbol 'car'
sCdr      = new Symbol 'cdr'
sSetCar   = new Symbol 'setcar'
sSetCdr   = new Symbol 'setcdr'

prox =
  "quote":   (body, env, mem, kont) -> evaluateQuote (cadr body), env, mem, kont
  "if":      (body, env, mem, kont) -> evaluateIf (cadr body), (caddr body), (cadddr body), env, mem, kont
  "begin":   (body, env, mem, kont) -> evaluateBegin (cdr body), env, mem, kont
  "set!":    (body, env, mem, kont) -> evaluateSet (intnvalu cadr body), (caddr body), env, mem, kont
  "lambda":  (body, env, mem, kont) -> evaluateLambda (intmksymbols cadr body), (cddr body), env, mem, kont
  "or":      (body, env, mem, kont) -> evaluateOr (cadr body), (caddr body), env, mem, kont

#  ___          _           _
# | __|_ ____ _| |_  _ __ _| |_ ___ _ _
# | _|\ V / _` | | || / _` |  _/ _ \ '_|
# |___|\_/\__,_|_|\_,_\__,_|\__\___/_|
#

transcode = (value, mem, qont) ->
  forms = [
    [intnullp, -> qont theEmptyList, mem],
    [((v) -> intsymbolp(v) and v in ['#t', '#f']), (-> qont (createBoolean value), mem)]
    [intsymbolp, (-> qont (createSymbol value), mem)]
    [intnumberp, (-> qont (createNumber value), mem)]
    [intstringp, (-> qont (createString value), mem)]
    [intlistp,   (-> transcode (car intnvalu value), mem, (addr, mem2) ->
      (transcode (cdr intvalu value), mem2, (d, mem3) ->
        (allocatePair addr, d, mem3, qont)))]
  ]
  found = (form[1] for form in forms when form[0](value))
  if found.length != 1
    throw new LispInterpreterError "Bad transcode match for #{value}"
  found[0]()

transcode2 = (value, mem, qont) ->
  forms = [
    [((v) -> v instanceof Symbol and v.name == 'null'), (-> qont theEmptyList, mem)],
    [((v) -> v instanceof Symbol and v.name in ['#t', '#f']), (-> qont (createBoolean value), mem)]
    [((v) -> v instanceof Symbol), (-> qont (createSymbol value), mem)]
    [((v) -> typeof v == 'string'), (-> qont (createString value), mem)]
    [((v) -> typeof v == 'number'), (-> qont (createNumber value), mem)]
    [((v) -> v.__type == 'list'), (-> transcode (car value), mem, (addr, mem2) ->
      (transcode (cdr value), mem2, (d, mem3) ->
        (allocatePair addr, d, mem3, qont)))]
  ]
  found = (form[1] for form in forms when form[0](value))
  if found.length < 1
    throw new LispInterpreterError "Bad transcode match for #{value}"
  found[0]()


transcodeBack = (value, mem) ->
  forms = [
    [sBoolean,  ((v) -> ((v sBoolify) true, false))]
    [sSymbol,   ((v) -> (v sName))]
    [sString,   ((v) -> (v sValue))]
    [sNumber,   ((v) -> (v sValue))]
    [sPair,     ((v) ->
      cons (transcodeBack (mem (v sCar)), mem), (transcodeBack (mem (v sCdr)), mem))]
    [sFunction, (v) -> v]
  ]
  found = (form[1] for form in forms when (eq (value sType), form[0]))
  if found.length != 1
    throw new LispInterpreterError "Bad transcode-back match for #{value}"
  found[0](value)

evaluate = (exp, env, mem, kont) ->
  if intatomp exp
    if intsymbolp exp
      evaluateVariable (intnvalu exp), env, mem, kont
    else
      evaluateQuote exp, env, mem, kont
  else
    body = intnvalu exp
    head = car body
    pname = (intnvalu head)
    if pname instanceof Symbol and prox[pname.name]?
      prox[pname.name](body, env, mem, kont)
    else
      evaluateApplication head, (cdr body), env, mem, kont

env_init = (id) ->
  throw new LispInterpreterError "No binding for " + id

# This is basically the core definition of 'mem': it returns a
# function enclosing the address (a monotomically increasing number as
# memory is allocated) and the value.  Update is passed the current
# memory, the address, and the value; it returns a function that says
# "If the requested address is my address, return my value, otherwise
# I'll call the memory handed to me at creation time with the address,
# and it'll go down the line."  Update basically adds to a 'stack'
# built entirely out of pointers to the base mem.

update = (mem, addr, value) ->
  (addra) -> if (eq addra, addr) then value else (mem addra)

updates = (mem, addrs, values) ->
  if (pairp addrs)
    updates (update mem, (car addrs), (car values)), (cdr addrs), (cdr values)
  else
    mem

# Memory location zero contains the position of the stack.

expandStore = (highLocation, mem) ->
  update mem, 0, highLocation

mem_init = expandStore 0, (a) ->
  throw new LispInterpreterError "No such address #{a}"

newLocation = (mem) ->
  (mem 0) + 1

evaluateVariable = (name, env, mem, kont) ->
  kont (mem (env name)), mem

evaluateSet = (name, exp, env, mem, kont) ->
  evaluate exp, env, mem, (value, mem2) ->
    kont value, (update mem2, (env name), value)

evaluateApplication = (exp, exprs, env, mem, kont) ->
  
  # In chapter 3, this was a series of jumping continuations chasing
  # each other.  Here, all of the continuations are kept in one place,
  # and the argument list is built by tail-calls to evaluateArguments
  # until the list is exhausted, at which point the continuation is
  # called.  The continuation is built in the second paragraph below.

  evaluateArguments = (exprs, env, mem, kont) ->
    if (pairp exprs)
      evaluate (car exprs), env, mem, (value, mem2) ->
        evaluateArguments (cdr exprs), env, mem2, (value2, mem3) ->
          kont (cons value, value2), mem3
    else
      kont cons(), mem

  evaluate exp, env, mem, (fun, mem2) ->
    evaluateArguments exprs, env, mem2, (value2, mem3) ->
      if eq (fun sType), sFunction
        (fun sBehavior) value2, mem3, kont
      else
        throw new LispInterpreterError "Not a function #{(car value2)}"

# Creates a memory address for the function, then creates a new memory
# address for each argument, then evaluates the expressions in the
# lambda, returning the value of the last one.

evaluateLambda = (names, exprs, env, mem, kont) ->
  allocate 1, mem, (addrs, mem2) ->
    kont (createFunction (car addrs), (values, mem, kont) ->
      if eq (length names), (length values)
        allocate (length names), mem, (addrs, mem2) ->
          evaluateBegin exprs, (updates env, names, addrs), (updates mem2, addrs, values), kont
      else
        throw new LispInterpreterError "Incorrect Arrity"), mem2

evaluateIf = (expc, expt, expf, env, mem, kont) ->
  evaluate expc, env, mem, (env, mems) ->
    evaluate ((env sBoolify) expt, expf), env, mems, kont

evaluateQuote = (c, env, mem, kont) ->
  transcode2 (normalizeForm c), mem, kont

# By starting over "from here," we undo all side-effect assignments
# that were effected by expression 1

evaluateOr = (exp1, exp2, env, mem, kont) ->
  evaluate exp1, env, mem, (value, mem2) ->
    ((value sBoolify) (-> kont value, mem2), (-> evaluate exp2, env, mem, kont))()

# I like how, in this version, we explicitly throw away the meaning of
# all but the last statement in evaluateBegin.
evaluateBegin = (exps, env, mem, kont) ->
  if pairp (cdr exps)
    evaluate (car exps), env, mem, (_, mems) ->
      evaluateBegin (cdr exps), env, mems, kont
  else
    evaluate (car exps), env, mem, kont

theEmptyList = (msg) ->
  switch msg
    when sType then sNull
    when sBoolify then (x, y) -> x

createBoolean = (value) ->
  combinator = if value then ((x, y) -> x) else ((x, y) -> y)
  (msg) ->
    switch msg
      when sType then sBoolean
      when sBoolify then combinator

createSymbol = (value) ->
  (msg) ->
    switch msg
      when sType then sSymbol
      when sName then value
      when sBoolify then (x, y) -> x

createNumber = (value) ->
  (msg) ->
    switch msg
      when sType then sNumber
      when sValue then value
      when sBoolify then (x, y) -> x

createString = (value) ->
  (msg) ->
    switch msg
      when sType then sString
      when sValue then value
      when sBoolify then (x, y) -> x

createFunction = (tag, behavior) ->
  (msg) ->
    switch msg
      when sType then sFunction
      when sBoolify then (x, y) -> x
      when sTag then tag
      when sBehavior then behavior

# I'm not sure I get the difference between allocate and update.
# Update appears to have the power to append to the memory list
# without updating highLocation.  If I'm reading this correct, then
# what we're actually looking at is a simulation of a memory
# subsystem, with expandStore/newLocation/allocate taking on the duty
# of "managing" our stack, and update actually just doing the managing
# the stack, and letting the garbage collector do its thing when a
# pointer to memory function goes out of scope.  In short: the
# allocate collection of functions is "going through the motions" of
# managing memory; had this been a real memory manager, you'd have
# a lot more work to do.

allocate = (num, mem, q) ->
  if (num > 0)
    do ->
      addr = newLocation mem
      allocate (num - 1), (expandStore addr, mem), (addrs, mem2) ->
        q (cons addr, addrs), mem2
  else
    q cons(), mem

allocateList = (values, mem, q) ->
  consify = (values, q) ->
    if (pairp values)
      consify (cdr values), (value, mem2) ->
        allocatePair (car values), value, mem2, q
    else
      q theEmptyList, mem
  consify values, q

allocatePair = (addr, d, mem, q) ->
  allocate 2, mem, (addrs, mem2) ->
    q (createPair (car addrs), (cadr addrs)), (update (update mem2, (car addrs), addr), (cadr addrs), d)

createPair = (a, d) ->
  (msg) ->
    switch msg
      when sType then sPair
      when sBoolify then (x, y) -> x
      when sSetCar then (mem, val) -> update mem, a, val
      when sSetCdr then (mem, val) -> update mem, d, val
      when sCar then a
      when sCdr then d

env_global = env_init
mem_global = mem_init

# The name is pushed onto the global environment, with a corresponding
# address.  The address is pushed onto the current memory, with the
# corresponding boxed value.

defInitial = (name, value) ->
  if typeof name == 'string'
    name = new Symbol name
  allocate 1, mem_global, (addrs, mem2) ->
    env_global = update env_global, name, (car addrs)
    mem_global = update mem2, (car addrs), value

defPrimitive = (name, arity, value) ->
  defInitial name, allocate 1, mem_global, (addrs, mem2) ->
    mem_global = expandStore (car addrs), mem2
    createFunction (car addrs), (values, mem, kont) ->
      if (eq arity, (length values))
        value values, mem, kont
      else
        throw new LispInterpreterError "Wrong arity for #{name}"

#  ___      _ _   _ _ _         _   _
# |_ _|_ _ (_) |_(_) (_)_____ _| |_(_)___ _ _
#  | || ' \| |  _| | | |_ / _` |  _| / _ \ ' \
# |___|_||_|_|\__|_|_|_/__\__,_|\__|_\___/_||_|
#


defInitial "#t", createBoolean true
defInitial "#f", createBoolean false
defInitial "nil", null

defPrimitive "<=", 2, (values, mem, kont) ->
  if (eq ((car values) sType), sNumber) and (eq ((cadr values) sName), sNumber)
    kont (createBoolean (((car values) sValue) <= ((cadr values) sValue))), mem
  else
    throw new LispInterpreterError "Comparison requires numbers"

defPrimitive "<", 2, (values, mem, kont) ->
  if (eq ((car values) sType), sNumber) and (eq ((cadr values) sName), sNumber)
    kont (createBoolean (((car values) sValue) < ((cadr values) sValue))), mem
  else
    throw new LispInterpreterError "Comparison requires numbers"

defPrimitive ">=", 2, (values, mem, kont) ->
  if (eq ((car values) sType), sNumber) and (eq ((cadr values) sName), sNumber)
    kont (createBoolean (((car values) sValue) >= ((cadr values) sValue))), mem
  else
    throw new LispInterpreterError "Comparison requires numbers"

defPrimitive ">", 2, (values, mem, kont) ->
  if (eq ((car values) sType), sNumber) and (eq ((cadr values) sName), sNumber)
    kont (createBoolean (((car values) sValue) > ((cadr values) sValue))), mem
  else
    throw new LispInterpreterError "Comparison requires numbers"

defPrimitive "=", 2, (values, mem, kont) ->
  if (eq ((car values) sType), sNumber) and (eq ((cadr values) sType), sNumber)
    kont (createBoolean (((car values) sValue) == ((cadr values) sValue))), mem
  else
    throw new LispInterpreterError "Comparison requires numbers"

defPrimitive "*", 2, (values, mem, kont) ->
  if (eq ((car values) sType), sNumber) and (eq ((cadr values) sName), sNumber)
    kont (createNumber (((car values) sValue) * ((cadr values) sValue))), mem
  else
    throw new LispInterpreterError "Multiplication requires numbers"

defPrimitive "+", 2, (values, mem, kont) ->
  if (eq ((car values) sType), sNumber) and (eq ((cadr values) sType), sNumber)
    kont (createNumber (((car values) sValue) + ((cadr values) sValue))), mem
  else
    throw new LispInterpreterError "Addition requires numbers"

defPrimitive "/", 2, (values, mem, kont) ->
  if (eq ((car values) sType), sNumber) and (eq ((cadr values) sName), sNumber)
    kont (createNumber (((car values) sValue) / ((cadr values) sValue))), mem
  else
    throw new LispInterpreterError "Division requires numbers"

defPrimitive "*", 2, (values, mem, kont) ->
  if (eq ((car values) sType), sNumber) and (eq ((cadr values) sName), sNumber)
    kont (createNumber (((car values) sValue) - ((cadr values) sValue))), mem
  else
    throw new LispInterpreterError "Subtraction requires numbers"

defPrimitive "cons", 2, (values, mem, kont) ->
  allocatePair (car values), (cadr values), mem, kont

defPrimitive "car", 1, (values, mem, kont) ->
  if (eq ((car values) sType) sPair)
    kont (mem ((car values) sCar)), mem
  else
    throw new LispInterpreterError "Not a pair"

defPrimitive "cdr", 1, (values, mem, kont) ->
  if (eq ((car values) sType) sPair)
    kont (mem ((car values) sCdr)), mem
  else
    throw new LispInterpreterError "Not a pair"

defPrimitive "setcdr", 2, (values, mem, kont) ->
  if (eq ((car values) sType) sPair)
    pair = (car values)
    kont pair, ((pair sSetCdr) mem, (cadr values))
  else
    throw new LispInterpreterError "Not a pair"

defPrimitive "setcar", 2, (values, mem, kont) ->
  if (eq ((car values) sType) sPair)
    pair = (car values)
    kont pair, ((pair sSetCar) mem, (cadr values))
  else
    throw new LispInterpreterError "Not a pair"

defPrimitive "eq?", 2, (values, mem, kont) ->
  kont createBoolean (
    if (eq ((car values) sType), ((cadr values) sType))
      switch ((car values) sType)
        when sBoolean
          ((car values) sBoolify) (((cadr values) sBoolify) true, false), (((cadr values) sBoolify) false, true)
        when sSymbol
          eq ((car values) sName), ((cadr values) sName)
        when sPair
          (((car values) sCar) == ((cadr values) sCar) and
           ((car values) sCdr) == ((cadr values) sCdr))
        when sFunction
          ((car values) sTag) == ((cadr values) sTag)
        else false
    else false)

defPrimitive "eqv?", 2, (values, mem, kont) ->
  kont createBoolean (
    if (eq ((car values) sType), ((cadr values) sType))
      switch ((car values) sType)
        when sBoolean
          ((car values) sBoolify) (((cadr values) sBoolify) true, false), (((cadr values) sBoolify) false, true)
        when sSymbol
          eq ((car values) sName), ((cadr values) sName)
        when sNumber
          ((car values) sValue) == ((cadr values) sValue)
        when sPair
          (((car values) sCar) == ((cadr values) sCar) and
           ((car values) sCdr) == ((cadr values) sCdr))
        when sFunction
          ((car values) sTag) == ((cadr values) sTag)
        else false
    else false)

module.exports = (ast, kont) ->
  evaluate ast, env_global, mem_global, (value, mem) ->
    kont (transcodeBack value, mem)
