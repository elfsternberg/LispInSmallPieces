(define (find-symbol id tree)
  (call/cc
   (lambda (exit) 
     (define (find tree)
       (if (pair? tree)
           (or (find (car tree)) (find (cdr tree)))
           (if (eq? tree id) (exit #t) #f)))
     (find tree))))
           
       
