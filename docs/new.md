This doesn't really look like the read/analyze/compile passes that one
expects of a modern Lisp.

Reading converts the source code into a list of immutable values in the
low-level AST of the system.  Reading and analysis must be combined if
there are to be reader macros (which I want to support).

... and then a miracle occurs ...

Compilation is the process of turning the AST into javascript.


