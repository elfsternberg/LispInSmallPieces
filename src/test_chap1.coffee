lisp = require './lisp_ch1'
{read, readForms} = require './reader'
{inspect} = require 'util'
ast = read("(begin (set! fact (lambda (x) (if (eq? x 0) 1 (* x (fact (- x 1)))))) (fact 5))")

# ast = read("(begin (if (lt 4 2) (+ 4 1)  (+ 2 1)))")
# ast = read("(begin (set! fact 4) fact)")
ast = read("(begin ((lambda (t) (if (lt t 2) (+ 4 1)  (+ 2 1))) 4))")
console.log "Result:",  (lisp ast)
