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

describe "Core interpreter #3: Try/Catch", ->
  it "doesn't change a simple value", ->
    expect(lisp read "(catch 'bar 1)").to.equal(1)
  it "doesn't interfere with standard behavior", ->
    expect(lisp read "(catch 'bar 1 2 3)").to.equal(3)
  it "bails at the top level when no catch", ->
    expect(-> lisp read "(throw 'bar 33)").to.throw("No associated catch")
  it "catches the right thing", ->
    expect(lisp read "(catch 'bar (throw 'bar 11))").to.equal(11)
  it "catches before the evaluation happens", ->
    expect(lisp read "(catch 'bar (* 2 (throw 'bar 5)))").to.equal(5)
  it "unrolls through multiple layers of the stack", ->
    expect(lisp read "((lambda (f) (catch 'bar (* 2 (f 5))) ) (lambda (x) (throw 'bar x)))").to.equal(5)
  it "continues at the right location", ->
    expect(lisp read "((lambda (f) (catch 'bar (* 2 (catch 'bar (* 3 (f 5))))) ) (lambda (x) (throw 'bar x)))").to.equal(10)
  it "throw/catch happens with unlabled catches", ->
    expect(lisp read "(catch 2 (* 7 (catch 1 (* 3 (catch 2 (throw 1 (throw 2 5)) )) )))").to.equal(105)
  it "bails at top level when there aren't enough catches", ->
    expect(-> lisp read "(catch 2 (* 7 (throw 1 (throw 2 3))))").to.throw("no test")

# describe "Core interpreter #3: Unwind-Protect", ->
#   it "protects the value correctly", ->
#     expect(lisp read "(unwind-protect 1 2").to.equal(1)
#   it "", ->
#     expect(lisp read "((lambda (c) (unwind-protect 1 (set! c 2)) c ) 0 ").to.equal(2)
#   it "", ->
#     expect(lisp read "((lambda (c) (catch 111 (* 2 (unwind-protect (* 3 (throw 111 5)) (set! c 1) ))) ) 0 ").to.equal(5)
#   it "", ->
#     expect(lisp read "((lambda (c) (catch 111 (* 2 (unwind-protect (* 3 (throw 111 5)) (set! c 1) ))) c ) 0 ").to.equal(1)
#   it "", ->
#     expect(lisp read "((lambda (c) (block A (* 2 (unwind-protect (* 3 (return-from A 5)) (set! c 1) ))) ) 0 ").to.equal(5)
#   it "", ->
#     expect(lisp read "((lambda (c) (block A (* 2 (unwind-protect (* 3 (return-from A 5)) (set! c 1) ))) c ) 0 ").to.equal(1)
# 
# 
# describe "Core interpreter #3: Try/Catch with Throw as a function", ->
#   contain = (fcall) ->
#     return "(begin ((lambda () (begin (set! funcall (lambda (g . args) (apply g args))) #{fcall}))))"
# 
#   it "", ->
#     expect(-> lisp read "(funcall throw 'bar 33").to.throw("bar")
#   it "", ->
#     expect(lisp read "(catch 'bar (funcall throw 'bar 11))").to.equal(11)
#   it "", ->
#     expect(lisp read "(catch 'bar (* 2 (funcall throw 'bar 5)))").to.equal(5)
#   it "", ->in
#     expect(lisp read "((lambda (f) (catch 'bar (* 2 (f 5))) ) (lambda (x) (funcall throw 'bar x))) ").to.equal(5)
#   it "", ->
#     expect(lisp read "((lambda (f) (catch 'bar (* 2 (catch 'bar (* 3 (f 5))))) ) (lambda (x) (funcall throw 'bar x)))) ").to.equal(10)
#   it "", ->
#     expect(lisp read "(catch 2 (* 7 (catch 1 (* 3 (catch 2 (funcall throw 1 (funcall throw 2 5)) )) ))) ").to.equal(105)
#   it "", ->
#     expect(lisp read "(catch 2 (* 7 (funcall throw 1 (funcall throw 2 3))))").to.equal(3)
#  
# 
#  
# 
