olisp = require '../chapter3g/interpreter'
{read, readForms} = require '../chapter1/reader'
{inspect} = require 'util'

lisp = (ast) ->
  ret = undefined
  olisp ast, (i) -> ret = i
  return ret

# console.log lisp read "(catch 2 (* 7 (catch 1 (* 3 (catch 2 (throw 1 (throw 2 5)) )) )))"

console.log lisp read "((lambda (c) (catch 111 (* 2 (unwind-protect (* 3 (throw 111 5)) (set! c 1) ))) ) 0)"
