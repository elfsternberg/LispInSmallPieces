olisp = require '../chapter3/interpreter'
{read, readForms} = require '../chapter1/reader'
{inspect} = require 'util'

lisp = (ast) ->
  ret = undefined
  olisp ast, (i) -> ret = i
  return ret

# console.log lisp read "(catch 2 (* 7 (catch 1 (* 3 (catch 2 (throw 1 (throw 2 5)) )) )))"

console.log lisp read "(catch foo (throw foo 33))"
console.log lisp read "(catch 'bar (throw 'bar 3))"
console.log lisp read "(catch 1 (throw 1 7))"
