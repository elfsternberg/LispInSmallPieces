{car, cdr, cons, nil, nilp, pairp, vectorToList, list} = require 'cons-lists/lists'
{length} = require 'cons-lists/reduce'
{inspect} = require "util"

NEWLINES   = ["\n", "\r", "\x0B", "\x0C"]
WHITESPACE = [" ", "\t"].concat(NEWLINES)

EOF = new (class Eof)()
EOO = new (class Eoo)()

stringp = (o) -> o?.__type == 'string'

errorp = (o) -> (pairp o) and (car o) == 'error'

streq = (s, t) -> String(s) == String(t)

class Source
  constructor: (@inStream) ->
    @index = 0
    @max = @inStream.length - 1
    @line = 0
    @column = 0

  peek: -> @inStream[@index]

  position: -> [@line, @column]

  next: ->
    c = @peek()
    return EOF if @done()
    @index++
    [@line, @column] = if @peek() in NEWLINES then [@line + 1, 0] else [@line, @column + 1]
    c

  done: -> @index > @max

# IO -> IO
skipWS = (inStream) ->
  while inStream.peek() in WHITESPACE then inStream.next()

invisibleProperty = (obj, name, value) ->
  Object.defineProperty obj, name,
    value: value
    configurable: false
    enumerable: false
    writable: false
  obj

lineInfo = (obj, line, column) ->
  invisibleProperty obj, '__position', {line: line, column: column}

# (type, value, line, column) -> (node {type, value, line, column)}
makeObj = (value, type, line, column) ->
  lineInfo (invisibleProperty value, '__type', type), line, column

# msg -> (IO -> Node => Error)
handleError = (message) ->
  (line, column) -> lineInfo (cons "error", message), line, column

# IO -> Node => Comment
readComment = (inStream) ->
  [line, column] = inStream.position()
  r = (while inStream.peek() != "\n" and not inStream.done()
    inStream.next()).join("")
  if not inStream.done()
    inStream.next()
  makeObj (new String r), 'comment', line, column

# IO -> (Node => Literal => String) | Error
readString = (inStream) ->
  [line, column] = inStream.position()
  inStream.next()
  string = until streq(inStream.peek(), '"') or inStream.done()
    if (streq inStream.peek(), '\\')
      inStream.next()
    inStream.next()
  if inStream.done()
    return handleError("end of file seen before end of string.")(line, column)
  inStream.next()
  makeObj (new String (string.join '')), 'string', line, column

# (String) -> (Node => Literal => Number) | Nothing
readMaybeNumber = (symbol) ->
  if streq(symbol[0], '+')
    return readMaybeNumber symbol.substr(1)
  if streq(symbol[0], '-')
    ret = readMaybeNumber symbol.substr(1)
    return if ret? then -1 * ret else undefined
  if symbol.search(/^0x[0-9a-fA-F]+$/) > -1
    return parseInt(symbol, 16)
  if symbol.search(/^0[0-9a-fA-F]+$/) > -1
    return parseInt(symbol, 8)
  if symbol.search(/^[0-9]+$/) > -1
    return parseInt(symbol, 10)
  if symbol.search(/^nil$/) > -1
    return nil
  undefined

# (IO, macros) -> (IO, Node => Number | Symbol) | Error
readSymbol = (inStream, tableKeys) ->
  [line, column] = inStream.position()
  symbol = (until (inStream.done() or inStream.peek() in tableKeys or inStream.peek() in WHITESPACE)
    inStream.next()).join ''
  number = readMaybeNumber symbol
  if nilp number
    return nil
  if number?
    return makeObj (new Number number), 'number', line, column
  makeObj (new String symbol), 'symbol', line, column


# (Delim, TypeName) -> IO -> (IO, node) | Error
makeReadContainer = (delim, constructor) ->
  # IO -> (IO, Node) | Error
  (inStream) ->
    inStream.next()
    skipWS inStream
    [line, column] = inStream.position()
    if streq(inStream.peek(), delim)
      inStream.next()
      return constructor(nil, line, column)

    # IO -> (IO, Node) | Error
    dotted = false
    readInContainer = (inStream) ->
      [line, column] = inStream.position()
      obj = read inStream, true, null, true
      if streq(inStream.peek(), delim)
        if dotted then return obj
        return lineInfo (cons obj, nil), line, column
      if inStream.done() then return handleError("Unexpected end of input")(line, column)
      if dotted then return handleError("More than one symbol after dot")
      return obj if (errorp obj)
      if streq(obj, ".")
        dotted = true
        return readInContainer inStream
      cons obj, readInContainer inStream

    ret = readInContainer(inStream)
    inStream.next()
    ret

# Type -> (IO -> (IO, Node))
#
# Handles the quoted symbol things.
#
prefixReader = (type) ->
  # IO -> (IO, Node)
  (inStream) ->
    [line, column] = inStream.position()
    inStream.next()
    [line1, column1] = inStream.position()
    obj = read inStream, true, null, true
    return obj if (car obj) == 'error'
    cons (makeObj (new String type), 'symbol', line1, column1), obj

# I really wanted to make anything more complex than a list (like an
# object or a vector) something handled by a read macro.  Maybe in a
# future revision I can vertically de-integrate these.

readMacros =
  '"': readString
  '(': makeReadContainer ')', (o, l, c) -> lineInfo o, l, c
  ')': handleError "Closing paren encountered"
  '[': makeReadContainer ']', (o, l, c) -> cons("vector", lineinfo o, l, c)
  ']': handleError "Closing bracket encountered"
  '{': makeReadContainer '}', (o, l, c) ->
    if length(o) % 2 != 0
      return handleError "Records require an even number of items."
    cons('record', lineinfo o, l, c)
  '}': handleError "Closing curly without corresponding opening."
  "`": prefixReader 'back-quote'
  "'": prefixReader 'quote'
  ",": prefixReader 'unquote'
  ";": readComment


# Given a stream, reads from the stream until a single complete lisp
# object has been found and returns the object
# IO -> Form
read = (inStream, eofErrorP = false, eofError = EOF,
        recursiveP = false, inReadMacros = null, keepComments = false) ->
  inStream = if inStream instanceof Source then inStream else new Source inStream
  inReadMacros = if InReadMacros? then inReadMacros else readMacros
  inReadMacroKeys = (i for i of inReadMacros)

  c = inStream.peek()

  # (IO, Char) -> (IO, Node) | Error
  matcher = (inStream, c) ->
    if inStream.done()
      return if recursiveP then handleError('EOF while processing nested object')(inStream) else nil
    if c in WHITESPACE
      inStream.next()
      return nil
    if c == ';'
      return readComment(inStream)
    ret = if c in inReadMacroKeys then inReadMacros[c](inStream) else readSymbol(inStream, inReadMacroKeys)
    skipWS inStream
    ret

  while true
    form = matcher inStream, c
    skip = (not nilp form) and (car form == 'comment') and not keepComments
    break if (not skip and not nilp form) or inStream.done()
    c = inStream.peek()
    null
  form

# readForms assumes that the string provided contains zero or more
# forms.  As such, it always returns a list of zero or more forms.

# IO -> (Form* | Error)
readForms = (inStream) ->
  inStream = if inStream instanceof Source then inStream else new Source inStream
  return nil if inStream.done()

  # IO -> (FORM*, IO) | Error
  [line, column] = inStream.position()
  readEach = (inStream) ->
    obj = read inStream, true, null, false
    return nil if (nilp obj)
    return obj if (car obj) == 'error'
    cons obj, readEach inStream

  obj = readEach inStream
  if (car obj) == 'error' then obj else makeObj "list", obj, line, column

exports.read = read
exports.readForms = readForms
