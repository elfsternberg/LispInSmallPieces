chai = require 'chai'
chai.should()
expect = chai.expect 

lisp = require '../chapter1/interpreter'
{read, readForms} = require '../chapter1/reader'

describe "Core interpreter", ->
  it "Should handle if statements", ->
    expect(lisp read "(begin (if (lt 0 1) #t #f))").to.equal(true)
    expect(lisp read "(begin (if (lt 1 0) #t #f))").to.equal(false)
    expect(lisp read '(begin (if (lt 1 0) "y" "n"))').to.equal("n")
    expect(lisp read '(begin (if (lt 0 1) "y" "n"))').to.equal("y")
    expect(lisp read '(begin (if (eq "y" "y") "y" "n"))').to.equal("y")
    expect(lisp read '(begin (if (eq "y" "x") "y" "n"))').to.equal("n")
      
  it "Should handle basic arithmetic", ->
    expect(lisp read '(begin (+ 5 5))').to.equal(10)
    expect(lisp read '(begin (* 5 5))').to.equal(25)
    expect(lisp read '(begin (/ 5 5))').to.equal(1)
    expect(lisp read '(begin (- 9 5))').to.equal(4)

  it "Should handle some algebra", ->
    expect(lisp read '(begin (* (+ 5 5) (* 2 3))').to.equal(60)

  it "Should handle a basic setting", ->
    expect(lisp read '(begin (set! fact 4) fact)').to.equal(4)

  it "Should handle a zero arity thunk", ->
    expect(lisp read '(begin (set! fact (lambda () (+ 5 5))) (fact))').to.equal(10)

  it "Should handle a two arity thunk", ->
    expect(lisp read '(begin (set! fact (lambda (a b) (+ a b))) (fact 4 6))').to.equal(10)

  it "Should handle a recursive function", ->
    expect(lisp read '(begin (set! fact (lambda (x) (if (eq? x 0) 1 (* x (fact (- x 1)))))) (fact 5))').to.equal(120)

  it "Should handle an IIFE", ->
    expect(lisp read '(begin ((lambda () (+ 5 5))))').to.equal(10)
    
