{cons} = require "cons-lists/lists"
lisp = require '../chapter3/interpreter'
{read, readForms} = require '../chapter1/reader'
{inspect} = require 'util'

lisp read('(begin ((lambda () (+ 5 5))))'), (x) -> console.log(x)
