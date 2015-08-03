{car, cdr, listp} = require 'cons-lists/lists'
{Node, Symbol} = require "./reader_types"

module.exports = ops =
  astObject: (form) -> form instanceof Node
  aValue:  (form) ->   form.value
  aSymbol: (form) ->   form.value
  isAList: (form) ->   ops.astObject(form) and form.type == 'list'
  isARecord: (form) -> ops.astObject(form) and form.type == 'record'
  isAVector: (form) -> ops.astObject(form) and form.type == 'vector'
