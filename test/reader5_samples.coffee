{cons, nil} = require "cons-lists/lists"
exports.samples = [
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
  # ['(1 2 3', 'error']
  ['{"foo" "bar"}', {foo: "bar"}]
]

