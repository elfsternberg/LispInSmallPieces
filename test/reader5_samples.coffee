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
  ['(1 (2 3) 4)', cons(1, cons(cons(2, cons(3)), cons(4)))]
  ['(   1   2   )', cons(1, (cons 2))]
  ['("a" "b")', cons("a", (cons "b"))]
  ['("a" . "b")', cons("a", "b")]
  ['[]', []]
  ['{}', {}]
  ['{"a" [1 2 3] "b" {"c" "d"} "c" ("a" "b" . "c")}', {"a": [1,2,3], "b":{"c": "d"}, "c": cons("a", cons("b", "c"))}]
  ['[1 2 3]', [1, 2, 3]]
  ['[1 2 [3 4] 5]', [1, 2, [3, 4], 5]]
  # ['(1 2 3', 'error']
  ['{"foo" "bar"}', {foo: "bar"}]
]

