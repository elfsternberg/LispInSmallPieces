{listToString, listToVector, pairp, cons, car, cdr, caar, cddr, cdar,
 cadr, caadr, cadar, caddr, nilp, nil, setcdr,
 metacadr, setcar} = require "cons-lists/lists"
{map} = require "cons-lists/reduce"
{length} = require "cons-lists/reduce"
{Node, Comment, Symbol} = require '../chapter5/reader_types'
{inspect} = require 'util'

itap = (a) -> console.log inspect a, true, null, false; a
ftap = (a) -> console.log Function.prototype.toString.call(a); a


class Value
  vpos = 0
  constructor: (@v) ->
    vpos = vpos + 1

inValue = (f) ->
  new Value(f)

class LispInterpreterError extends Error
  name: 'LispInterpreterError'
  constructor: (@message) ->

the_false_value = (cons "false", "boolean")

eq = (id1, id2) ->
  if id1 instanceof Symbol and id2 instanceof Symbol
    return id1.name == id2.name
  id1 == id2

cadddr = metacadr('cadddr')

# Hack
gsym = (x) -> if (x instanceof Symbol) then x.name else x

consp = (e) ->
  ((pairp e) and (typeof (car e) == 'number') and
  ((car e) > 0) and (pairp cdr e) and (typeof (cadr e) == 'number') and
  ((cadr e) > 0) and (nilp cddr e))

convert = (exp, store) ->
  conv = (e) ->
    if consp e
      cons (conv (store (car e)).v), (conv (store (cadr e)).v)
    else
      if symbolp e then e.name
      else if stringp e then '"' + e | '"'
      else e
  conv exp.v

# 5.2.4
# f[y → z] = λx . if y = x then z else f(x) endif
# 
# Accepts a parent function, and ID and a value.  Returns a function
# that takes a request ID.  If the request ID equals the ID above,
# return the value, else call the parent function with the request
# ID.
#
# Calls allocate 

extend = (next, id, value) ->
  (x) -> if (eq x, id) then value else (next x)

# f[y* → z*] = if #y>0 then f[y*†1 → z*†1][y*↓1 → z*↓1] else f endif
#
# Helper.  Builds a stack of extend() functions, at tail of which it
# appends the parent function.
#
#
lextends = (fn, ids, values) ->
  if (pairp ids)
    extend (lextends fn, (cdr ids), (cdr values)), (car ids), (car values)
  else
    fn

translate = (exp, store, qont) ->
  if (pairp exp)
    translate (car exp), store, (val1, store1) ->
      translate (cdr exp), store1, (val2, store2) ->
        allocate store2, 2, (store, addrs) ->
          qont (inValue addrs), (extend (extend store, (car addrs), val1), (cadr addrs), val2)
  else
    qont (inValue exp), store
  
# Allocate is a function that takes a store, a number of addresses to
# allocate within that store, and a continuation; at the end, it calls
# the continuation with the store object and the new addresses.
        
allocate = (->
  loc = 0
  (store, num, qont) ->
    aloop = (n, a) ->
      if (n > 0)
        loc = loc - 1
        aloop (n - 1), (cons loc, a)
      else
        qont store, a
    aloop(num, cons()))()


listp =     (cell) -> cell.__type == 'list'
atomp =     (cell) -> not (cell.__type?) or (not cell.__type == 'list')
symbolp =   (cell) -> cell instanceof Symbol
commentp =  (cell) -> typeof cell == 'string' and cell.length > 0 and cell[0] == ";"
numberp =   (cell) -> typeof cell == 'number'
stringp =   (cell) -> typeof cell == 'string' and cell.length > 0 and cell[0] == "\""
boolp =     (cell) -> typeof cell == 'boolean'
nullp =     (cell) -> cell == null
vectorp =   (cell) -> (not straight_evaluation.listp cell) and toString.call(cell) == '[object Array]'
recordp =   (cell) -> (not cell._prototype?) and toSTring.call(cell) == '[object Object]'
objectp =   (cell) -> (cell._prototype?) and toString.call(cell) == '[object Object]'
nilp =      (cell) -> nilp(cell)
nvalu =     (cell) -> cell
mksymbols = (cell) -> cell

sBehavior = new Symbol 'behavior'
sBoolean  = new Symbol 'boolean'
sBoolify  = new Symbol 'boolify'
sFunction = new Symbol 'function'
sSymbol   = new Symbol 'symbol'
sString   = new Symbol 'string'
sQuote    = new Symbol 'quote'
sLambda   = new Symbol 'lambda'
sIf       = new Symbol 'if'
sValue    = new Symbol 'value'
sChars    = new Symbol 'chars'
sBegin    = new Symbol 'begin'
sName     = new Symbol 'name'
sNumber   = new Symbol 'number'
sNull     = new Symbol 'null'
sTag      = new Symbol 'tag'
sSet      = new Symbol 'set'
sType     = new Symbol 'type'
sValue    = new Symbol 'value'
sPair     = new Symbol 'pair'
sCar      = new Symbol 'car'
sCdr      = new Symbol 'cdr'
sSetCar   = new Symbol 'setcar'
sSetCdr   = new Symbol 'setcdr'

ValueToFunction = (e) ->
  c = e.v
  if (typeof c == 'function') then c else throw new LispInterpreterError("Not a function: " + Object.toString(c))

ValueToPair = (e) ->
  c = e.v
  if pairp c then c else throw new LispInterpreterError("Not a pair: " + Object.toString(c))

ValueToNumber = (e) ->
  c = parseInt(e.v, 10)
  if (typeof c == 'number') then c else throw new LispInterpreterError("Not a number: " + Object.toString(c))

ValueToPrimitive = (e) ->
  return e.v

store_init = (a) -> throw new LispInterpreterError "No such address: #{a}"
env_init = (a) -> throw new LispInterpreterError "No such variable: #{a}"  

class Interpreter
  constructor: ->
    arity_check = (name, arity, fn) =>
      (values, kont, store) =>
        if not eq (length values), arity
          throw new LispInterpreterError "Incorrect Arity for #{name}"
        fn(values, kont, store)

    @definitial "cons", inValue arity_check "cons", 2, (values, kont, store) =>
      allocate store, 2, (store, addrs) =>
        kont (inValue (cons (car addrs), (cadr addrs))), (lextends store, addrs, values)
  
    @definitial "car", inValue arity_check "car", 1, (values, kont, store) =>
      kont (store car @valueToPair (car values)), store
  
    @definitial "cdr", inValue arity_check "car", 1, (values, kont, store) =>
      kont (store cadr @valueToPair (car values)), store
  
    @defprimitive "pair?", ((v) -> inValue (consp v.v)), 1
    @defprimitive "eq?", ((v1, v2) -> inValue (eq v1.v, v2.v)), 2
    @defprimitive "symbol?", ((v) -> inValue (symbolp v.v)), 1
  
    @definitial "set-car!", inValue arity_check, "set-car!", 2, (values, kont, store) ->
      kont (car values), (extend store, (car (ValueToPair (car values))), (cadr values))
  
    @definitial "set-cdr!", inValue arity_check, "set-cdr!", 2, (values, kont, store) ->
      kont (car values), (extend store, (cadr (ValueToPair (car values))), (cadr values))

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
        if pairp v.v
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

    @definitial "x", inValue (new Object(null))
    @definitial "y", inValue (new Object(null))
    @definitial "z", inValue (new Object(null))
    @definitial "a", inValue (new Object(null))
    @definitial "b", inValue (new Object(null))
    @definitial "c", inValue (new Object(null))
    @definitial "foo", inValue (new Object(null))
    @definitial "bar", inValue (new Object(null))
    @definitial "hux", inValue (new Object(null))
    @definitial "fib", inValue (new Object(null))
    @definitial "fact", inValue (new Object(null))
    @definitial "visit", inValue (new Object(null))
    @definitial "length", inValue (new Object(null))
    @definitial "filter", inValue (new Object(null))
    @definitial "primes", inValue (new Object(null))

  meaning: (e) ->
    meaningTable =
      "quote":  ((e) => @meaningQuotation (cadr e))
      'lambda': ((e) => @meaningAbstraction (cadr e), (cddr e))
      'if':     ((e) => @meaningAlternative (cadr e), (caddr e), (cadddr e))
      'begin':  ((e) => @meaningSequence (cdr e))
      'set!':   ((e) => @meaningAssignment (cadr e), (caddr e))

    if (atomp e)
      return if (symbolp e) then (@meaningReference gsym(e)) else (@meaningQuotation e)
    n = gsym(car e)
    if meaningTable[n]?
      meaningTable[n](e)
    else
      @meaningApplication (car e), (cdr e)

  meaningSequence: (exps) =>
    (env, kont, store) =>
      (@meaningsSequence exps) env, kont, store

  meaningsMultipleSequence: (exp, exps) ->
    (env, kont, store) =>
      hkont = (values, store1) =>
        (@meaningsSequence exps) env, kont, store1
      (@meaning exp) env, hkont, store

  meaningsSingleSequence: (exp) ->
    (env, kont, store) =>
      (@meaning exp) env, kont, store

  meaningsSequence: (exps) ->
    if not (pairp exps)
      throw new LispInterpreterError("Illegal Syntax")
    if pairp cdr exps
      @meaningsMultipleSequence (car exps), (cdr exps)
    else
      @meaningsSingleSequence (car exps)

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
    name = if name instanceof Symbol then name.name else name
    console.log(name)
    (env, kont, store) =>
      hkont = (val, store1) ->
        kont val, (extend store1, (env name), val)
      (@meaning exp) env, hkont, store

  # Abstraction (keeps a lambda)

  meaningAbstraction: (names, exps) ->
    (env, kont, store) =>
      funcrep = (vals, kont1, store1) =>
        if not (eq (length vals), (length names))
          throw new LispInterpreterError("Incorrect Arity.")
        argnamestostore = (store2, addrs) =>
          (@meaningsSequence exps) (lextends env, names, addrs), kont1, (lextends store2, addrs, vals)
        allocate store1, (length names), argnamestostore
      kont (inValue funcrep), store

  meaningVariable: (name) ->
    (m) ->
      (vals, env, kont, store) ->
        allocate store, 1, (store, addrs) ->
          addr = (car addrs)
          m (cdr vals), (extend env, names, addr), kont, (extend store, addr, (car vals))

  meaningApplication: (exp, exps) ->
    (env, kont, store) =>
      hkont = (func, store1) =>
        kont2 = (values, store2) ->
          (ValueToFunction func) values, kont, store2
        (@meanings exps) env, kont2, store1
      (@meaning exp) env, hkont, store

  meanings: (exps) =>
    meaningSomeArguments = (exp, exps) =>
      (env, kont, store) =>
        hkont = (value, store1) =>
          hkont2 = (values, store2) ->
            kont (cons value, values), store2
          (@meanings exps) env, hkont2, store1
        (@meaning exp) env, hkont, store

    meaningNoArguments = ->
      (env, kont, store) ->
        kont (cons()), store

    if pairp exps
      meaningSomeArguments (car exps), (cdr exps)
    else
      meaningNoArguments()

  definitial: (name, value) ->
    allocate store_init, 1, (store, addrs) ->
      env_init = extend env_init, name, (car addrs)
      store_init = extend store, (car addrs), value
      name

  defprimitive: (name, value, arity) ->
    callable = (values, kont, store) =>
      if not eq arity, (length values)
        throw new LispInterpreterError "Incorrect Arity for #{name}"
      kont (value.apply(null, listToVector(values))), store
    @definitial name, (inValue callable)

  defarithmetic: (name, value, arity) ->
    callable = (values, kont, store) ->
      if not eq arity, (length values)
        throw new LispInterpreterError "Incorrect Arity for #{name}"
      kont (inValue (value.apply(null, listToVector(map values, ValueToNumber)))), store
    @definitial name, (inValue callable)

module.exports = (ast, kont) ->
  interpreter = new Interpreter()
  store_current = store_init
  (interpreter.meaning ast)(env_init,
    ((value, store_final) -> kont (convert value, store_final)), store_current)

