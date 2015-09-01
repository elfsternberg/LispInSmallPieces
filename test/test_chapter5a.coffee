chai = require 'chai'
chai.should()
expect = chai.expect

olisp = require '../chapter5/interpreter5a'
{read} = require '../chapter5/reader'

lisp = (ast) ->
  ret = undefined
  olisp ast, (i) -> ret = i
  return ret

describe "Core interpreter #5: Now with more λ!", ->
  it "Understands symbol inequality", ->
    expect(lisp read "(eq? 'a 'b)").to.equal(false)
  it "Understands symbol equality", ->
    expect(lisp read "(eq? 'a 'a)").to.equal(true)
  it "Understands separate allocation inequality", ->
    expect(lisp read "(eq? (cons 1 2) (cons 1 2))").to.equal(false)
  it "Understands address equality of values", ->
    expect(lisp read "((lambda (a) (eq? a a)) (cons 1 2))").to.equal(true)
  it "Understands address equality of functions", ->
    expect(lisp read "((lambda (a) (eq? a a)) (lambda (x) x))").to.equal(true)
  it "Understands function inequality", ->
    expect(lisp read "(eq? (lambda (x) 1) (lambda (x y) 2))").to.equal(false)


