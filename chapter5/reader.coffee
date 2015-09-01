{car, cdr, cons, nil, nilp, pairp, vectorToList, list} = require 'cons-lists/lists'
{inspect} = require "util"
{Comment, Symbol} = require "../chapter5/reader_types"

NEWLINES   = ["\n", "\r", "\x0B", "\x0C"]
WHITESPACE = [" ", "\t"].concat(NEWLINES)

EOF = new (class Eof)()
EOO = new (class Eoo)()

class ReadError extends Error
  name: 'LispInterpreterError'
  constructor: (@message) ->

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

readMaybeNumber = (symbol) ->
  if symbol[0] == '+'
    return readMaybeNumber symbol.substr(1)
  if symbol[0] == '-'
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

# (Delim, TypeName) -> IO -> (IO, Node) | Errorfor
makeReadPair = (delim, type) ->
  # IO -> (IO, Node) | Error
  (inStream) ->
    inStream.next()
    skipWS inStream
    if inStream.peek() == delim
      inStream.next() unless inStream.done()
      return if type then cons((new Symbol type), nil) else nil

    # IO -> (IO, Node) | Error
    dotted = false
    readEachPair = (inStream) =>
      obj = @read inStream, true, null, true
      if inStream.peek() == delim
        if dotted then return obj
        return cons obj, nil
      return obj if obj instanceof ReadError
      if inStream.done() then return new ReadError "Unexpected end of input"
      if dotted then return new ReadError "More than one symbol after dot in list"
      if @acc(obj) instanceof Symbol and @acc(obj).name == '.'
        dotted = true
        return readEachPair inStream
      cons obj, readEachPair inStream

    obj = readEachPair(inStream)
    inStream.next()
    if type then cons((new Symbol type), obj) else obj

# Type -> IO -> IO, Node

class Reader
  prefixReader = (type) ->
    # IO -> IO, Node
    (inStream) ->
      inStream.next()
      obj = @read inStream, true, null, true
      return obj if obj instanceof ReadError
      list((new Symbol type), obj)

  "acc": (obj) -> obj

  "symbol": (inStream) ->
    symbol = (until (inStream.done() or @[inStream.peek()]? or inStream.peek() in WHITESPACE)
      inStream.next()).join ''
    number = readMaybeNumber symbol
    if number?
      return number
    new Symbol symbol

  "read": (inStream, eofErrorP = false, eofError = EOF, recursiveP = false, keepComments = false) ->
    inStream = if inStream instanceof Source then inStream else new Source inStream

    c = inStream.peek()

    # (IO, Char) -> (IO, Node) | Error
    matcher = (inStream, c) =>
      if inStream.done()
        return if recursiveP then (new ReadError 'EOF while processing nested object') else nil
      if c in WHITESPACE
        inStream.next()
        return nil
      if c == ';'
        return readComment(inStream)
      ret = if @[c]? then @[c](inStream) else @symbol(inStream)
      skipWS inStream
      ret

    while true
      form = matcher inStream, c
      skip = (not nilp form) and (form instanceof Comment) and not keepComments
      break if (not skip and not nilp form) or inStream.done()
      c = inStream.peek()
      null
    form

  '(': makeReadPair ')', null

  '[': makeReadPair ']', 'vector'

  '{': makeReadPair('}', 'record', (res) ->
    res.length % 2 == 0 and true or mkerr "record key without value")

  '"': (inStream) ->
    inStream.next()
    s = until inStream.peek() == '"' or inStream.done()
      if inStream.peek() == '\\'
        inStream.next()
      inStream.next()
    return (new ReadError "end of file seen before end of string") if inStream.done()
    inStream.next()
    s.join ''

  ')': (inStream) -> new ReadError "Closing paren encountered"

  ']': (inStream) -> new ReadError "Closing bracket encountered"

  '}': (inStream) -> new ReadError "Closing curly without corresponding opening."

  "`": prefixReader 'back-quote'

  "'": prefixReader 'quote'

  ",": prefixReader 'unquote'

  ";": (inStream) ->
    r = (while inStream.peek() != "\n" and not inStream.done()
      inStream.next()).join("")
    inStream.next() if not inStream.done()
    new Comment r

exports.Source = Source
exports.ReadError = ReadError
exports.Reader = Reader
reader = new Reader()
exports.read = -> reader.read.apply(reader, arguments)
