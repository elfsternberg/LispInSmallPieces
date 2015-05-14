lispeval = require './eval'
{cons, car, cdr, nilp, nil, cadar, cadr, caddr} = require './lists'
{create_lisp_expression_evaluator, create_vm_expression_evaluator, create_special_form_evaluator} = require './fn'

scope = cons
  '+': create_vm_expression_evaluator scope, [], (a, b) -> a + b
  '-': create_vm_expression_evaluator scope, [], (a, b) -> a - b
  '*': create_vm_expression_evaluator scope, [], (a, b) -> a * b
  '/': create_vm_expression_evaluator scope, [], (a, b) -> a / b
  '==': create_vm_expression_evaluator scope, [], (a, b) -> a == b
  '#t': true
  '#f': false

  'define': create_special_form_evaluator scope, [], (nodes, scope) ->
    current = (car scope)
    current[(cadar nodes)] = lispeval((cadr nodes), scope)

  'lambda': create_special_form_evaluator scope, [], (nodes, scope) ->
    param_nodes = cadar nodes
    reducer = (l) ->
      if (nilp l) then nil else cons (cadar l), reducer(cdr l)
    param_names = reducer(param_nodes)
    create_lisp_expression_evaluator scope, param_names, (cdr nodes)
        
  'if': create_special_form_evaluator scope, [], (nodes, scope) ->
    if lispeval (car nodes), scope
      lispeval (cadr nodes), scope
    else
      lispeval (caddr nodes), scope

module.exports = scope
