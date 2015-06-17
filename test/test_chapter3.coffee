lisp = require './interpreter'
{read, readForms} = require '../chapter1/reader'
{inspect} = require 'util'

ast = read("(begin (set! fact (lambda (x) (if (eq? x 0) 1 (* x (fact (- x 1)))))) (fact 5))")

# ast = read("(begin (if (lt 4 5) (+ 4 1)  (+ 2 1)))")
# ast = read("(begin (set! fact 4) fact)")
# ast = read("(begin ((lambda (t) (if (lt t 2) (+ 4 1)  (+ 2 1))) 1))")

# ast = read("(begin (set! fact (lambda (x) (+ x x))) (fact 5))")
ast = read("(begin (set! fact (lambda (x) (- x 4))) (fact 5))")
# ast = read("(begin ((lambda () (+ 5 5))))")

lisp(ast,  (r) -> console.log("Result:", r))  
