{Reader, ReadError, Source} = require './reader'
{Node} = require './reader_types'

liftToTrack = (f) ->
  (ioStream) ->
    ioStream = if ioStream instanceof Source then ioStream else new Source ioStream
    [line, column] = ioStream.position()
    obj = f.apply(this, arguments)
    if obj instanceof ReadError
      obj['line'] = line
      obj['column'] = column
      return obj
    if obj instanceof Node then obj else new Node obj, line, column

TrackingReader = class
for own key, func of Reader::
  TrackingReader::[key] = liftToTrack(func)

exports.ReadError = ReadError  
exports.Reader = TrackingReader
exports.reader = reader = new TrackingReader()
exports.read = -> reader.read.apply(reader, arguments)
