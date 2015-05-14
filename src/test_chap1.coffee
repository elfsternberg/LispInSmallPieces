lisp = require './lisp_ch1'
{read, readForms} = require './reader'
{inspect} = require 'util'
ast = read("(begin (set! fact (lambda (x) (if (eq? x 0) 1 (* x (fact (- x 1)))))) (fact 5))")
console.log "Result:",  (lisp ast)
