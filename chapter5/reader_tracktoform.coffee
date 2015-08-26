{Node} = require './reader_types'
{Normalize} = require './reader_rawtoform'

liftToNode = (f) ->
  (form) ->
    return f.call this, (if (form instanceof Node) then form.v else form)

NodeNormalize = class
for own key, func of Normalize::
  NodeNormalize::[key] = liftToNode(func)

exports.Normalize = NodeNormalize
normalize = new NodeNormalize()
exports.normalize = -> normalize.normalize.apply(normalize, arguments)
