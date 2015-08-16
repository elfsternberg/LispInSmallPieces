chai = require 'chai'
chai.should()
expect = chai.expect

{cons} = require "cons-lists/lists"
olisp = require '../chapter4/interpreter'
{read, readForms} = require '../chapter4/reader'

the_false_value = (cons "false", "boolean")

lisp = (ast) ->
  ret = undefined
  olisp ast, (i) -> ret = i
  return ret

describe "Core interpreter #4: Pure Lambda Memory", ->
  it "Understands equality", ->
    expect(lisp read "(eq? 'a 'b)").to.equal(false)
    expect(lisp read "(eq? 'a 'a)").to.equal(true)
    expect(lisp read "(eq? (cons 1 2) (cons 1 2))").to.equal(false)
    expect(lisp read "((lambda (a) (eq? a a)) (cons 1 2))").to.equal(true)
    expect(lisp read "((lambda (a) (eq? a a)) (lambda (x) x))").to.equal(true)
    expect(lisp read "(eq? (lambda (x) 1) (lambda (x y) 2))").to.equal(false)

  it "Understands equivalence", ->
    expect(lisp read "(eqv? '1 '2)").to.equal(false)
    expect(lisp read "(eqv? 1 1)").to.equal(true)
    expect(lisp read "(eqv? 'a 'b)").to.equal(false)
    expect(lisp read "(eqv? 'a 'a)").to.equal(true)
    expect(lisp read "(eqv? (cons 1 2) (cons 1 2))").to.equal(false)
    expect(lisp read "((lambda (a) (eqv? a a)) (cons 1 2))").to.equal(true)
    expect(lisp read "((lambda (a) (eqv? a a)) (lambda (x) x))").to.equal(true)
    expect(lisp read "(eqv? (lambda (x) 1) (lambda (x y) 2))").to.equal(false)

  it "Does special OR (backtracking without side-effect)", ->
    expr1 = "((lambda (x) (or (begin (set! x (+ x 1)) #f) (if (= x 1) \"OK\" \"KO\"))) 1)"
    expect(lisp read expr1).to.equal("OK")
    expr2 = "((lambda (x) (or (begin (set! x (+ x 1)) #f) (if (= x 1) (begin (set! x 3) x) \"KO\"))) 1)"
    expect(lisp read expr2).to.equal(3)

