chai = require 'chai'
chai.should()
expect = chai.expect

{cons} = require "cons-lists/lists"
olisp = require '../chapter3g/interpreter'
{read, readForms} = require '../chapter1/reader'

the_false_value = (cons "false", "boolean")

lisp = (ast) ->
  ret = undefined
  olisp ast, (i) -> ret = i
  return ret
  
describe "Core interpreter #3: Unwind-Protect", ->
  it "protects the value correctly", ->
    expect(lisp read "(unwind-protect 1 2").to.equal(1)
   it "", ->
     expect(lisp read "((lambda (c) (unwind-protect 1 (set! c 2)) c ) 0 ").to.equal(2)
   it "", ->
     expect(lisp read "((lambda (c) (catch 111 (* 2 (unwind-protect (* 3 (throw 111 5)) (set! c 1) ))) ) 0 ").to.equal(5)
   it "", ->
     expect(lisp read "((lambda (c) (catch 111 (* 2 (unwind-protect (* 3 (throw 111 5)) (set! c 1) ))) c ) 0 ").to.equal(1)
   it "", ->
     expect(lisp read "((lambda (c) (block A (* 2 (unwind-protect (* 3 (return-from A 5)) (set! c 1) ))) ) 0 ").to.equal(5)
   it "", ->
     expect(lisp read "((lambda (c) (block A (* 2 (unwind-protect (* 3 (return-from A 5)) (set! c 1) ))) c ) 0 ").to.equal(1)
 
 
describe "Core interpreter #3: Try/Catch with Throw as a function", ->
  contain = (fcall) ->
    return "(begin ((lambda () (begin (set! funcall (lambda (g . args) (apply g args))) #{fcall}))))"

  it "", ->
    expect(-> lisp read "(funcall throw 'bar 33").to.throw("bar")
  it "", ->
    expect(lisp read "(catch 'bar (funcall throw 'bar 11))").to.equal(11)
  it "", ->
    expect(lisp read "(catch 'bar (* 2 (funcall throw 'bar 5)))").to.equal(5)
  it "", ->
    expect(lisp read "((lambda (f) (catch 'bar (* 2 (f 5))) ) (lambda (x) (funcall throw 'bar x))) ").to.equal(5)
  it "", ->
    expect(lisp read "((lambda (f) (catch 'bar (* 2 (catch 'bar (* 3 (f 5))))) ) (lambda (x) (funcall throw 'bar x)))) ").to.equal(10)
  it "", ->
    expect(lisp read "(catch 2 (* 7 (catch 1 (* 3 (catch 2 (funcall throw 1 (funcall throw 2 5)) )) ))) ").to.equal(105)
  it "", ->
    expect(lisp read "(catch 2 (* 7 (funcall throw 1 (funcall throw 2 3))))").to.equal(3)
 
 
  
 

