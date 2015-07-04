{car, cdr} = require 'cons-lists/lists'

symbol = (form) -> (car form)

module.exports =
  aSymbol: symbol
  aValue:  (form) -> (car cdr form)
  isAList: (form) -> (symbol form) == 'list'
  isARecord: (form) -> (symbol form) == 'record'
  isAVector: (form) -> (symbol form) == 'vector'
