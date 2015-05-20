{listToString, listToVector, pairp, cons, car, cdr, caar, cddr, cdar, cadr, caadr, cadar, caddr, nilp, nil, setcdr, metacadr} = require "cons-lists/lists"

ntype = (node) -> car node
nvalu = (node) -> cadr node

evlis = (exps, d) ->
  if (pairp exps) then evaluate((car exps), d) + " " + evlis((cdr exps), d) else ""

indent = (d) ->
  ([0..d].map () -> " ").join('')
    
evaluate = (e, d = 0) ->
  [type, exp] = [(ntype e), (nvalu e)]
  if type == "symbol" then exp
  else if type in ["number", "boolean"] then exp
  else if type == "string" then '"' + exp + '"'
  else if type == "list" then "\n" + indent(d) + "(" + evlis(exp, d + 2) + ")"
  else throw "Don't recognize a #{type}"
    
module.exports = (c) -> evaluate c, 0
  
