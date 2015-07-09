chai = require 'chai'
chai.should()
expect = chai.expect

{cons} = require "cons-lists/lists"
olisp = require '../chapter3/interpreter'
{read, readForms} = require '../chapter1/reader'

the_false_value = (cons "false", "boolean")

lisp = (ast) ->
  ret = undefined
  olisp ast, (i) -> ret = i
  return ret

describe "Core interpreter #3: Blocks", ->
  it "Should handle simple blocks", ->
    expect(lisp read "(block foo 33)").to.equal(33)
  it "Should handle the last blocks", ->
    expect(lisp read "(block foo 1 2 3)").to.equal(3)
  it "Should handle expressive blocks", ->
    expect(lisp read "(block foo (+ 5 5))").to.equal(10)
  it "Should handle basic returns blocks", ->
    expect(lisp read "(block foo (+ 1 (return-from foo 2)))").to.equal(2)
  it "Should handle complex returns blocks", ->
    code = "(block foo ((lambda (exit)(* 2 (block foo (* 3 (exit 5)) )) ) (lambda (x) (return-from foo x)) ) )"
    expect(lisp read code).to.equal(5)
  it "Expects an uninitialized return-from to fail", ->
    expect(-> lisp read "(return-from foo 3)").to.throw("Unknown block label foo")
  it "Expects to see an obsolete block when called late", ->
    expect(-> lisp read "((block foo (lambda (x) (return-from foo x))) 3 )")
      .to.throw("Obsolete continuation")
  it "Expects to see an obsolete block when called late", ->
    blocka = "((block a  (* 2 (block b (return-from a (lambda (x) (return-from b x))))) )3 )"
    expect(-> lisp read blocka).to.throw("Obsolete continuation")
  it "Expects to see an obsolete block when called late", ->
    blockb = "((block a (* 2 (block b (return-from a (lambda (x) (return-from a x))))) ) 3 )"
    expect(-> lisp read blockb).to.throw("Obsolete continuation")

    
