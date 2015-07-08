# A Collection of Interpreters from Lisp In Small Pieces, written in Coffeescript

## Purpose

I don't know Lisp, so I figured the correct place to start was to write
my own interpreter.  After buying five different textbooks (*The
Structure and Interpretation of Computer Programs*, aka "The Wizard
Book", Friedman's *The Essentials of Programming Languages*, *Let over
Lambda*, *On Lisp*, and one more) I decided Christian Quinnec's *Lisp In
Small Pieces* gave the clearest step-by-step introduction.

Since I didn't know Lisp, my task was to translate what Quiennec wrote
in his book into a language I *did* know: Javascript.  Well,
Coffeescript, which is basically Javascript with a lot of the
syntactical noise removed, which is why I liked it.

## Usage

I don't know if you're going to get much out of it, but the reader
(which I had to write by hand, seeing as I didn't *have* a native Lisp
reader on hand in my Javascripty environment), and each interpreter has
a fairly standard test case that demonstrates that each language does
what it says it does: you can do math, set variables, name and create
functions, and even do recursion.

## Notes

chapter-lambda-1 is not from Lisp In Small Pieces.  It is a primitive
CPS interpreter built on top of the interpreter from LiSP Chapter 1,
using techniques derived from a fairly facile reading of 
<a href="http://lisperator.net/pltut/">Lisperator's "Implement A
Programming Language in Javascript."</a>  But it was fun.

## LICENSE AND COPYRIGHT NOTICE: NO WARRANTY GRANTED OR IMPLIED

See the LICENSE file.

