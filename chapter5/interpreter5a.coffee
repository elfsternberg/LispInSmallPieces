{listToString, listToVector, pairp, cons, car, cdr, caar, cddr, cdar,
 cadr, caadr, cadar, caddr, nilp, nil, setcdr,
 metacadr, setcar} = require "cons-lists/lists"
{map} = require "cons-lists/reduce"
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

consp = (e) ->
  ((pairp e) and (typeof (car e) == 'number') and
  ((car e) > 0) and (pairp cdr e) and (typeof (cadr e) == 'number') and
  ((cadr e) > 0) and (nilp cddr e))

convert = (exp, store) ->
  conv = (e) ->
    if consp e
      cons (conv content.v, (store (car e))), (conv content.v, (store (cadr e)))
    else
      e
  conv (content.v e)

translate = (exp, store, qont) ->
  if (pairp exp)
    translate (car exp), store, (val1, store1) ->
      translate (cdr exp), store1, (val2, store2) ->
        
allocate = (->
  loc = 0
  (store, num, qont) ->
    addrs = cons()
    n = num
    until n <= 0
      loc = loc + 1
      n = n - 1
      cons loc, addrs
    qont store, addrs)()

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

class Value
  constructor: (@content) ->

inValue = (f) ->
  new Value(f)

ValueToFunction = (e) ->
  c = e.content
  if (typeof c == 'function') then c else throw new LispInterpreterError("Not a function: " + Object.toString(c))

ValueToPair = (e) ->
  c = e.content
  if pairp c then c else throw new LispInterpreterError("Not a pair: " + Object.toString(c))

ValueToNumber = (e) ->
  c = e.content
  if (typeof c == 'number') then c else throw new LispInterpreterError("Not a number: " + Object.toString(c))

  
class Interpreter
  constructor: ->
    arity_check = (name, arity, fn) =>
      (values, kont, store) =>
        if not eq (length values), arity
          throw new LispInterpreterError "Incorrect Arity for #{name}"
        fn.call(@, values, kont, store)

    @definitial "cons", inValue arity_check "cons", 2, (values, kont, store) =>
      allocate store, 2, (store, addrs) =>
        kont (inValue (cons (car addr), (cadr addr))), (@extends store, addrs, values)
  
    @definitial "car", inValue arity_check "car", 1, (values, kont, store) =>
      kont (store car @valueToPair (car values)), store
  
    @definitial "cdr", inValue arity_check "car", 1, (values, kont, store) =>
      kont (store cadr @valueToPair (car values)), store
  
    @defprimitive "pair?", ((v) -> inValue (consp v.content)), 1
    @defprimitive "eq?", ((v1, v2) -> inValue (eq v1.content, v2.content)), 2
    @defprimitive "symbol?", ((v) -> inValue (symbolp v.content)), 1
  
    @definitial "set-car!", inValue arity_check, "set-car!", 2, (values, kont, store) =>
      kont (car values), (@extend store, (car (ValueToPair (car values))), (cadr values))
  
    @definitial "set-cdr!", inValue arity_check, "set-cdr!", 2, (values, kont, store) =>
      kont (car values), (@extend store, (cadr (ValueToPair (car values))), (cadr values))
  
    @defarithmetic "+",  ((x, y) -> x + y),  2
    @defarithmetic "-",  ((x, y) -> x - y),  2
    @defarithmetic "*",  ((x, y) -> x * y),  2
    @defarithmetic "/",  ((x, y) -> x / y),  2
    @defarithmetic "<",  ((x, y) -> x < y),  2
    @defarithmetic ">",  ((x, y) -> x > y),  2
    @defarithmetic "=",  ((x, y) -> x == y), 2
    @defarithmetic "<=", ((x, y) -> x <= y), 2
    @defarithmetic ">=", ((x, y) -> x >= y), 2
    @defarithmetic "%",  ((x, y) -> x % y),  2
  
    @definitial "apply", arity_check "apply", 2, inValue (values, kont, store) ->
      flat = (v) ->
        if pairp v.content
          cons (store (car (ValueToPair v))), (flat (store (cadr (ValueToPair v))))
        else
          cons()

      collect = (values) ->
        if nullp cdr values
          flat car values
        else
          cons (car values), (collect cdr values)

      (ValueToFunction (car values)) (collect (cdr values)), kont, store

    @definitial '#t', (inValue true)
    @definitial '#f', (inValue false)
    @definitial 'nil', (inValue cons())

    @definitial "x", null
    @definitial "y", null
    @definitial "z", null
    @definitial "a", null
    @definitial "b", null
    @definitial "c", null
    @definitial "foo", null
    @definitial "bar", null
    @definitial "hux", null
    @definitial "fib", null
    @definitial "fact", null
    @definitial "visit", null
    @definitial "length", null
    @definitial "primes", null
    @loc = 0

  loc: 0     # For allocate
    
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

  meaning: (e) ->

    meaningTable = [
      [sQuote,  ((e) => @meaningQuotation (cadr e))]
      [sLambda, ((e) => @meaningAbstraction (cadr e), (cddr e))]
      [sIf,     ((e) => @meaningAlternative (cadr e), (caddr e), (cadddr e))]
      [sBegin,  ((e) => @meaningSequence (cdr e))]
      [sSet,    ((e) => @meaningAssignment (cadr e), (caddr e))]
    ]

    if @atomp e
      if @symbolp e then (@meaningReference e) else (@meaningQuotation e)
    else
      found = (form[1] for form in forms when form[0](e))
      if found.length == 1 then found[0](e) else @meaningApplication (car e), (cdr e)

  meaningQuotation: (val) ->
    (env, kont, store) ->
      (translate val, store, kont)

  meaningReference: (name) ->
    (env, kont, store) ->
      kont (store (env name)), store

  # Extensional alternative

  meaningAlternative: (exp1, exp2, exp3) ->
    boolify = (value) ->
      if (eq? value (inValue false)) then ((x, y) -> y) else ((x, y) -> x)

    ef = (val, val1, val2) ->
      val val1, val2

    (env, kont, store) =>
      hkont = (val, store1) =>
        ef (boolify val), ((@meaning exp2) env, kont, store1), ((@meaning exp3) env, kont, store1)
      (@meaning exp1)(env, hkont, store)

  # Assignment

  meaningAssignment: (name, exp) ->
    (env, kont, store) =>
      hkont = (val, store1) ->
        kont value, (extend store1, (env name), val)

      (@meaning exp)(env, hkont, store)

  # Abstraction (keeps a lambda)

  meaningAbstraction: (names, exps) ->
    (env, kont, store) =>
      funcrep = (vals, kont1, store1) =>
        if not (eq (length vals), (length names))
          throw new LispInterpreterError("Incorrect Arity.")
        functostore = (store2, addrs) =>
          (@meaningsSequence exps) (@extends env, names, addrs), kont1, (@extends store2, addrs, vals)
        allocate store1, (length names), functostore
      kont inValue, funcrep

  meaningVariable: (name) ->
    (m) =>
      (vals, env, kont, store) =>
        allocate store, 1, (store, addrs) =>
          addr = (car addrs)
          m (cdr vals), (@extend env, names, addr), kont, (@extend store, addr, (car vals))

  meaningApplication: (exp, exps) ->
    (env, kont, store) =>
      hkont = (func, store1) =>
        kont2 = (values, store2) ->
          (ValueToFunction func) values, kont, store2
        (@meaning exps) env, kont2, store1
      (@meaning exp) env, hkont, store

  meaningSequence: (exps) ->
    meaningsMultipleSequence = (exp, exps) =>
      (env, kont, store) =>
        hkont = (values, store1) ->
          (meaningsSequence exps) env, kont, store1
        (@meaning exp) env, hkont, store

    meaningsSingleSequence = (exp) =>
      (env, kont, store) =>
        (@meaning exp) env, kont, store

    (env, kont, store) ->
      if not (pairp exps)
        throw new LispInterpreterError("Illegal Syntax")
      if pairp cdr exps
        meaningsMultipleSequence (car exps), (cdr exps)
      else
        meaningSingleSequence (car exps)

  meanings: (exps) =>
    meaningSomeArguments = (exp, exps) =>
      (env, kont, store) =>
        hkont = (value, store1) ->
          hkont2 = (values, store2) ->
            kont (cons value, values), store2
          (@meanings exps) env, khont2, store1
        (@meaning exp) env, hkont, store

    meaningNoArguments = (env, kont, store) -> (k (cons()), store)

    if pairp exps
      meaningSomeArguments (car exps), (cdr exps)
    else
      meaningNoArgument()

  extend: (fn, pt, im) ->
    (x) -> if (eq pt, x) then im else (fn x)

  extends: (fn, pts, ims) ->
    if (pairp pts)
      @extend (@extends fn, (cdr pts), (cdr ims)), (car pts), (car ims)
    else
      fn

  store_init: (a) -> throw new LispInterpreterError "No such address"
  env_init: (a) -> throw new LispInterpreterError "No such variable"

  definitial: (name, value) ->
    allocate @store_init, 1, (store, addrs) =>
      @env_init = @extend @env_init, name, (car addrs)
      @store_init = @extend store, (car addrs), value

  defprimitive: (name, value, arity) ->
    callable = (values, kont, store) =>
      if not eq(arity, (length values))
        throw new LispInterpreterError "Incorrect Arity for #{name}"
      kont (inValue (value.apply(@, [ValueToNumber(v) for v in values]))), store
    @definitial name, (inValue callable)

  defarithmetic: (name, value, arity) ->
    callable = (values, kont, store) ->
      if not eq arity, (length values)
        throw new LispInterpreterError "Incorrect Arity for #{name}"
      kont (inValue (apply value, (map ValueToIngeter, values))), store
    (@defprimitive name, value, arity) (name), inValue callable

module.exports = (ast, kont) ->
  interpreter = new Interpreter()
  (meaning ast) @interpreter.env_init, (value, store_final) ->
    kont (convert value, store_final)

