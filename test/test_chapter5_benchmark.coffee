chai = require 'chai'
chai.should()
expect = chai.expect

olisp = require '../chapter5/interpreter5a'
{read} = require '../chapter5/reader'

lisp = (ast) ->
  ret = undefined
  olisp ast, (i) -> ret = i
  return ret

benchmark = [
  "(begin",
  "  (set! primes",
  "        (lambda (n f max)",
  "          ((lambda (filter)",
  "             (begin",
  "               (set! filter (lambda (p)",
  "                              (lambda (n) (= 0 (remainder n p))) ))",
  "               (if (> n max)",
  "                   '()",
  "                   (if (f n)",
  "                       (primes (+ n 1) f max)",
  "                       (cons n",
  "                             ((lambda (ff)",
  "                                (primes (+ n 1)",
  "                                        (lambda (p) (if (f p) t (ff p)))",
  "                                        max ) )",
  "                              (filter n) ) ) ) ) ) )",
  "           'wait ) ) )",
  "  (primes 2 (lambda (x) f) 50) )"].join('')

  
describe "Chapter 5: It runs.", ->
  it "Runs the primes search example", ->
    expect(lisp read benchmark).to.equal(true)
