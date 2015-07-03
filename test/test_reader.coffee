chai = require 'chai'
chai.should()
expect = chai.expect 

{cons, nil, nilp} = require "cons-lists/lists"
{read, readForms} = require '../chapter1/reader'
{normalizeForm} = require '../chapter1/astToList'

describe "Core reader functions", ->
  samples = [
    ['nil', nil]
    ['0', 0]
    ['1', 1]
    ['500', 500]
    ['0xdeadbeef', 3735928559]
    ['"Foo"', 'Foo']
    ['(1)', cons(1)]
    ['(1 2)', cons(1, (cons 2))]
    ['(1 2 )', cons(1, (cons 2))]
    ['( 1 2 )', cons(1, (cons 2))]
    ['(   1   2   )', cons(1, (cons 2))]
    ['("a" "b")', cons("a", (cons "b"))]
    ['("a" . "b")', cons("a", "b")]
    ['[]', []]
    ['{}', {}]
    ['[1 2 3]', [1, 2, 3]]
    ['{foo "bar"}', {foo: "bar"}]
  ]

  for [t, v] in samples
    do (t, v) ->
      it "should interpret #{t} as #{v}", ->
        res = normalizeForm read t
        expect(res).to.deep.equal(v)
