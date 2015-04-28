; Lisp In Small Pieces, chapter 1 Simple Lambda Calculus interpreter
; with global environment, simple lexical closures enforced by singly
; linked lists.

; This covers only severals exercise: I added 'exit as an exit value;
; I fixed the definition of '<', and then applied the exercise out of 
; the book.

; Any of the exercises that needed call/cc I've avoided for the simple
; reason that I started this to learn lisp, I'm a raw beginner, and 
; call/cc is definitely advance estorics.

; Needed for 'wrong-syntax', which is Racket's version of the "wrong"
; exception tosser.

(require racket/syntax)

; LISP requires a mutatable environment, so using mcons/mpair for
; that.

(require scheme/mpair)

; Weird; racket needs this as a patch.  I would have expected it as
; present in the default list of functions!

(define (atom? x)
  (and (not (null? x))
       (not (pair? x))))

(define env_init '())

(define env_global env_init)

; So, this macro places *into the current scope* (i.e. no building of
; a new scope that gets reaped upon exit) the names of variables and
; potential initial values.

(define-syntax definitial
  (syntax-rules ()
    ((definitial name)
     (begin (set! env_global (mcons (mcons 'name 'void) env_global)) 'name))
    ((definitial name value)
     (begin (set! env_global (mcons (mcons 'name value) env_global)) 'name))))

; Oh! This macro (same scope thing again) associates named things with
; values in the target environment (the host language), along with
; arity checking.  (which it doesn't do for 'if', for example)

(define-syntax defprimitive
  (syntax-rules ()
    ((defprimitive name value arity)
     (definitial name 
       (lambda (values)
         (if (= arity (length values))
             (apply value values)
             (wrong-syntax #'here "Incorrect arity ~s" (list 'name values))))))))

; Sometimes, you do have to define something before you use it. Lesson
; learned.

(define the-false-value (cons "false" "boolean"))

(definitial t #t)
(definitial f the-false-value)
(definitial nil '())
(definitial foo)
(definitial bar)
(definitial fib)
(definitial fact)

(define-syntax defpredicate
  (syntax-rules ()
    ((_ name native arity)
     (defprimitive name (lambda args (or (apply native args) the-false-value)) arity))))

(defprimitive cons cons 2)
(defprimitive car car 1)
(defprimitive set-cdr! set-mcdr! 2)
(defprimitive + + 2)
(defprimitive - - 2)
(defprimitive * * 2)
(defpredicate lt < 2)
(defpredicate eq? eq? 2)

; This function extends the environment so that *at this moment of
; extension* the conslist head points to the old environment, then
; when it's done it points to the new environment.  What's interesting
; is that the conslist head points to the last object initialized, not
; the first.

(define (extend env variables values) 
  (cond ((pair? variables)
         (if (pair? values) 
             (mcons (mcons (car variables) (car values))
                    (extend env (cdr variables) (cdr values)))
             (wrong-syntax #'here "Too few values")))
        ((null? variables)
         (if (null? values) 
             env 
             (wrong-syntax #'here "Too many values")))
        ((symbol? variables) (mcons (mcons variables values) env))))
                         
; Already we're starting to get some scope here.  Note that
; make-function provides the environment, not the invoke.  This makes
; this a lexically scoped interpreter.

(define (make-function variables body env) 
  (lambda (values) 
    (eprogn body (extend env variables values))))

; if it's a function, invoke it.  Wow. Much complex. Very interpret.

(define (invoke fn args) 
  (if (procedure? fn)
      (fn args)
      (wrong-syntax #'here "Not an function ~s" fn)))

; Iterate through the exps, return the value of the last one.

(define (eprogn  exps env)
  (if (pair? exps)
      (if (pair? (cdr exps))
          (begin (evaluate (car exps) env)
                 (eprogn (cdr exps) env))
          (evaluate (car exps) env))
      '()))
  
; Iterate through the exps, return a list of the values of the
; evaluated expressions

(define (evlis exps env)
  (if (pair? exps) 
      (cons (evaluate (car exps) env)
            (evlis (cdr exps) env))
      '()))

; silly patch because of the mutatable lists

(define-syntax mcaar (syntax-rules () ((_ e) (mcar (mcar e)))))
(define-syntax mcdar (syntax-rules () ((_ e) (mcdr (mcar e)))))

; Iterate through the environment, find an ID, return its associated
; value.

(define (lookup id env)
  (if (mpair? env)
      (if (eq? (mcaar env) id)
          (mcdar env)
          (lookup id (mcdr env)))
      (wrong-syntax #'here "No such binding ~s" id)))

; Iterate through the environment, find an ID, and change its value to
; the new value.  Again, purely global environment.  Really starting
; to grok how the environment "stack" empowers modern runtimes.

(define (update! id env value)
  (if (mpair? env)
      (if (eq? (mcaar env) id)
          (begin (set-mcdr! (mcar env) value) value)
          (update! id (mcdr env) value))
      (wrong-syntax #'here "No such binding ~s" id)))

; Core evaluation rules.

(define (evaluate exp env)
  (if (atom? exp)
      (cond 
       ((symbol? exp) (lookup exp env))
       ((or (number? exp) (string? exp) (char? exp) (boolean? exp) (vector? exp)) exp)
       (else (wrong-syntax #'here "Cannot evaluate")))
      (case (car exp)
        ((quote) (cadr exp))
        ; Note: No checks that the statement even vaguely resembles the rules.
        ((if) (if (not (eq? (evaluate (cadr exp) env) the-false-value))
                  (evaluate (caddr exp) env)
                  (evaluate (cadddr exp) env)))
        ((begin) (eprogn (cdr exp) env))
        ((set!) (update! (cadr exp) env (evaluate (caddr exp) env)))
        ((lambda) (make-function (cadr exp) (cddr exp) env))
        (else (invoke (evaluate (car exp) env) (evlis (cdr exp) env))))))

; Run it.  Note that the function toplevel is self-referential.

(define (chapter1-scheme)
  (define (toplevel)
    (let ((result (evaluate (read) env_global)))
      (if (not (eq? result 'exit))
          (begin (display result) (toplevel))
          #f)))
  (toplevel))

; (set! fact (lambda (x) (if (eq? x 0) 1 (* x (fact (- x 1))))))
