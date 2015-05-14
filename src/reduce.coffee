{car, cdr, cons, pairp, nilp, nil, list, listToString} = require './lists'

reduce = (lst, iteratee, memo, context) ->
  count = 0
  ptr = lst
  while not nilp ptr
    [item, ptr] = [(car ptr), (cdr ptr)]
    memo = iteratee.call(context, memo, item, count, lst)
    count++
  iteratee.call(context, memo, nil, count, lst)

map = (lst, iteratee, context) ->
  return nil if nilp lst
  root = cons("")

  reducer = (memo, item, count) ->
    next = cons(iteratee.call(context, item, count, lst))
    memo[1] = next
    next

  reduce(lst, reducer, root, context)
  (cdr root)

rmap = (lst, iteratee, context) ->
  reducer = (memo, item, count) ->
    cons(iteratee.call(context, item, count, lst), memo)
  reduce(lst, reducer, nil, context)


filter = (lst, iteratee, context) ->
  return nil if nilp lst
  root = cons("")

  reducer = (memo, item, count) ->
    if iteratee.call(context, item, count, lst)
      next = cons(item)
      memo[1] = next
      next
    else
      memo

  reduce(lst, reducer, root, context)
  (cdr root)

module.exports =
  reduce: reduce
  map: map
  rmap: rmap
  filter: filter
  
