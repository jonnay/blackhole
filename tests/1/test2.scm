
(export mac)

(define (private-fun) #t)

(define-syntax private-mac
  (syntax-rules ()
    ((private-mac) #t)))

(define-syntax mac
  (syntax-rules ()
    ((mac) (and (private-mac) (private-fun)))))
