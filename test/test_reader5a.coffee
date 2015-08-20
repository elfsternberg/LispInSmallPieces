chai = require 'chai'
chai.should()
expect = chai.expect

{cons, nil, nilp} = require "cons-lists/lists"
{read} = require '../chapter5/reader'
{normalize} = require '../chapter5/reader_rawtoform'
{samples} = require './reader5_samples'

describe "Lisp reader functions", ->
  for [t, v] in samples
    do (t, v) ->
      it "should interpret #{t} as #{v}", ->
        res = normalize read t
        expect(res).to.deep.equal(v)
