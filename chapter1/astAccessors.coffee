{car, cdr, listp} = require 'cons-lists/lists'

symbol = (form) -> (car form)

module.exports =
  astObject: (form) -> typeof (car form) == "string"
  aSymbol: symbol
  aValue:  (form) -> (car cdr form)
  isAList: (form) -> (symbol form) == 'list'
  isARecord: (form) -> (symbol form) == 'record'
  isAVector: (form) -> (symbol form) == 'vector'
