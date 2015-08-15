{listToString, listToVector, pairp, cons, car, cdr, caar, cddr, cdar,
 cadr, caadr, cadar, caddr, nilp, nil, setcdr,
 metacadr, setcar} = require "cons-lists/lists"
{normalizeForms, normalizeForm} = require "../chapter1/astToList"
{Node, Symbol} = require '../chapter1/reader_types'

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

sType = new Symbol 'type'
sBehavior = new Symbol 'behavior'
sFunction = new Symbol 'function'

# Page 129
env_init = (id) -> throw LispInterpreterError "No binding for #{id}"

# Page 129
# We don't have an initial value for mem yet?
update = (mem, addr, value) ->
  (addra) -> if (addra == addr) then value else mem(addra)

# Page 130
updates = (mem, addrs, values) ->
  if (pairp addrs)
    updates (update mem, (car addrs), (car values)), (cdr addrs), (cdr values)
  else
    mem

# Page 130
evaluateVariable = (name, env, mem, kont) ->
  kont mem, (env name), mem

# Page 130
evaluateSet = (name, exp, env, mem, kont) ->
  evaluate exp, env, mem, (value, newmem) ->
    kont value, (update newmem, (env name), value)

# Page 131
# TODO: I don't know that I trust this.
evaluateApplication = (exp, exprs, env, mem, kont) ->

  evaluateArguments = (exprs, env, mem, kont) ->
    if (pairp exprs)
      evaluate (car exprs), env, mem, (value, mem2) ->
        evaluateArguments (cdr exprs), env, mem2, (value2, mems3) ->
          kont (cons value, value2), mems3
    else
      kont cons(), mem

  evaluate exp, env, mem, (fun, mems) ->
    evaluateArguments exprs, env, mems, (value2, mem3) ->
      if eq (fun sType), sFunction
        (fun sBehavior) value2, mem3, kont
      else
        throw new LispInterpreterError "Not a function #{(car value2)}"

evaluateLambda = (names, exprs, env, mem, kont) ->
  allocate 1, mem, (addrs, mem2) ->
    kont (createFunction (car addrs), (values, mem, kont) ->
      if eq (length names), (length values)
        allocate (length names), mem, (addrs, mem2) ->
          evaluateBegin exprs, (updates env, names, addrs), (updates mem2, addrs, values), kont
      else
        throw new LispInterpreterError "Incorrect Arrity"), mem2

allocate = (num, mem, q) ->
  if (num > 0)
    do ->
      addr = newLocation s
      allocate (num - 1), (expandStore addr, mem), (addrs, mem2) ->
        q (cons addr, addrs), mem2
  else
    q cons(), mem

expandStore = (highLocation, mem) ->
 update mem, 0, highLocation

newLocation = (mem) ->
  (mem 0) + 1          



# Page 128
evaluateIf = (expc, expt, expf, env, mem, kont) ->
  evaluate expc, env, mem, (env, mems) ->
    evaluate ((env "boolify") expt, expf), env, mems, kont

# Page 129
# I like how, in this version, we explicitly throw away the meaning of
# all but the last statement in evaluateBegin.  
evaluateBegin = (exps, env, mem, kont) ->
  if pairp (cdr exps)
    evaluate (car exps), env, mem, (_, mems) ->
      evaluateBegin (cdr exps), env, mems, kont
  else
    evaluate (car exps), env, mem, kont


prox = 
  "quote":   (body, env, mem, kont, ix) -> evaluateQuote (cadr body), env, mem, kont
  "if":      (body, env, mem, kont, ix) -> evaluateIf (cadr body), (caddr body), (cadddr body), env, mem, kont
  "begin":   (body, env, mem, kont, ix) -> evaluateBegin (cdr body), env, mem, kont
  "set!":    (body, env, mem, kont, ix) -> evaluateSet (ix.nvalu cadr body), (caddr body), env, mem, kont
  "lambda":  (body, env, mem, kont, ix) -> evaluateLambda (ix.mksymbols cadr body), (cddr body), env, mem, kont

makeEvaluator = (ix = straight_evaluation) ->
  (exp, env, mem, kont) ->
    if ix.atomp exp
      if ix.symbolp exp
        evaluateVariable exp, env, mem, kont
      else
        evaluateQuote exp, env, mem, kont
    else
      body = ix.nvalu exp
      head = car body
      if prox[(ix.nvalu head)]?
        prox[(ix.nvalue head)](body, env, mem, kont, ix)
      else
        evaluateApplication body, (cadr body), env, mem, kont
