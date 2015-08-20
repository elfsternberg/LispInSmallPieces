chai = require 'chai'
chai.should()
expect = chai.expect

{cons, nil, nilp} = require "cons-lists/lists"
{read} = require '../chapter5/tracking_reader'
{normalize} = require '../chapter5/reader_tracktoform'
{samples} = require './reader5_samples'

describe "Tracker reader functions", ->
  for [t, v] in samples
    do (t, v) ->
      it "should interpret #{t} as #{v}", ->
        res = normalize read t
        expect(res).to.deep.equal(v)
