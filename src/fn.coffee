lispeval = require './eval'
{cons, nil, nilp, car, cdr, listToVector} = require './lists'

module.exports = 
  create_vm_expression_evaluator: (defining_scope, params, body) ->
    (cells, scope) ->
      args = (amap = (cells, accum) ->
        return accum if nilp cells
        amap((cdr cells), accum.concat(lispeval (car cells), scope)))(cells, [])
      body.apply null, args

  create_lisp_expression_evaluator: (defining_scope, params, body) ->
    (cells, scope) ->

      # Takes the current scope, which has been passed in during the
      # execution phase, and evaluate the contents of the parameters
      # in the context in which this call is made (i.e. when the
      # function is *called*, rather than defined.

      new_scope = (cmap = (cells, params, nscope) ->
        return nscope if (nilp cells) or (nilp params)
        nscope[(car params)] = lispeval (car cells), scope
        cmap((cdr cells), (cdr params), nscope))(cells, params, {})

      # Execute and evaluate the body, creating an inner scope that
      # consists of: (1) the bound variables (the parameters)
      # evaluated in the context of the function call, because that's
      # where they were encountered (2) the free variables evaluated
      # in the context of the defining scope, because that's where
      # *they* were encountered.
      #
      # While this inspiration comes from Coglan, the clearest
      # explanation is from Lisperator's 'make_lambda' paragraph at
      # http://lisperator.net/pltut/eval1/

      inner_scope = cons(new_scope, defining_scope)
      (nval = (body, memo) ->
        return memo if nilp body
        nval((cdr body), lispeval((car body), inner_scope)))(body)

  create_special_form_evaluator: (defining_scope, params, body) ->
    (cells, scope) -> body(cells, scope)

