#lang racket

(require (for-syntax syntax/parse racket/syntax)
         syntax/parse
         racket/syntax)

;(provide (all-from-out racket))
(provide intersection ∩
         union ∪
         subtract //
         add ++
         primal->integer
         primal?
         primal=?
         cardinality
         disjoint?
         partition?
         add
         #%app
         ^
         #%datum
         #%top
         #%top-interaction
         quote
         #%module-begin
         list
         cons
         λ
         define
         apply
         require)

(define ^ '^)

(define-syntax (#%app stx)
  (syntax-parse stx #:literals (^)
    [(_ (a ^ b) ...)
     #'(list (cons a b) ...)]
    [(_ e args ...) #'(#%plain-app e args ...)]))

(define primal->integer
  (λ (fact)
    (cond
      [(null? fact) 0]
      [else (* (expt (caar fact) (cdar fact)) (if (null? (cdr fact))
                                                  1
                                                  (primal->integer (cdr fact))))])))

(define cardinality
  (λ (fact)
    (length fact)))

(define disjoint?
  (λ (fact1 fact2)
    (eqv? 0 (cardinality (intersection fact1 fact2)))))

(define primal?
  (λ (fact)
    (cond
      [(null? fact) #t]
      [else (and (natural-prime? (caar fact))
                 (natural? (cdar fact))
                 (primal? (cdr fact)))])))

(define natural-prime?
  (λ (num)
    (letrec ([helper
              (λ (num num-root cur)
                (cond
                  [(> cur num-root) #t]
                  [else (and (not (divisible? num cur))
                             (helper num num-root (add1 cur)))]))])
      (and (natural? num)
           (or (< num 3)
               (helper num (sqrt 7) 2))))))

(define primal=?
  (λ (p1 p2)
    (equal? (primal->integer p1) (primal->integer p2))))

(define divisible?
  (λ (a b)
    (integer? (/ a b))))

(define contains-v
  (λ (fact num)
    (cond
      [(null? fact) 0]
      [else (if (eqv? num (car (car fact)))
                (cdr (car fact))
                (contains-v (cdr fact) num))])))


;                         ;                                                    ;                           
;                         ;                                                    ;                           
;     ;;;;                ;                                                    ;     ;                     
;       ;                 ;;                                                   ;;                          
;       ;                 ;;;                                                  ;;;                         
;       ;     ;         ;;;;                                                 ;;;;                  ;       
;       ;     ;   ;;      ;;     ;;;;     ;        ;;;;    ;;;;      ;;;;      ;;    ;      ;;;;   ;   ;;  
;       ;     ;   ; ;     ;;    ;;  ;     ;   ;;  ;;      ;;  ;     ;   ;;     ;;    ;    ;;    ;  ;   ; ; 
;       ;     ;  ;  ;     ;;    ;    ;    ;  ;   ;        ;    ;    ;    ;     ;;    ;   ;;     ;  ;  ;  ; 
;       ;     ; ;   ;      ;   ;    ;;    ; ;;   ;       ;    ;;   ;            ;    ;  ;;      ;  ; ;   ; 
;       ;      ;;   ;      ;   ;;;;;      ;;;     ;;     ;;;;;     ;            ;    ;  ;       ;   ;;   ; 
;       ;      ;    ;      ;   ;          ;;        ;;   ;         ;            ;    ;  ;       ;   ;    ; 
;       ;      ;    ;      ;   ;      ;    ;          ;  ;      ;  ;     ;      ;    ;  ;      ;    ;    ; 
;       ;;;    ;    ;      ;    ;   ;;     ;          ;   ;   ;;    ;   ;       ;    ;  ;      ;    ;    ; 
;       ;;     ;    ;      ;     ;;;;      ;     ;;  ;;    ;;;;      ;;;        ;    ;   ;    ;     ;    ; 
;     ;;                                          ;;;;                                    ;;;;             
(define ∩
  (λ args
    (apply intersection args)))
(define intersection
  (λ args
    (cond
      [(< (length args) 2) '()]
      [(eqv? (length args) 2) (intersection-helper (car args) (cadr args))]
      [else
       (apply intersection (intersection-helper (car args) (cadr args)) (cddr args))])))

(define intersection-helper
  (λ (fact1 fact2)
    (letrec ([helper
              (λ (fact1 fact2 res)
                (cond
                  [(null? fact1) res]
                  [else (let* ([fact1-a (car (car fact1))]
                               [fact1-d (cdr (car fact1))]
                               [v (contains-v fact2 fact1-a)]
                               [min-v (min fact1-d v)])
                          (if (eqv? min-v 0)
                              (helper (cdr fact1) fact2 res)
                              (helper (cdr fact1) fact2 (append res (list (cons fact1-a min-v))))))]))])
      (helper fact1 fact2 '()))))


                                     
;                                               
;                         ;                     
;    ;      ;                                   
;    ;      ;                                   
;    ;      ;   ;                       ;       
;    ;      ;   ;   ;;    ;      ;;;;   ;   ;;  
;    ;      ;   ;   ; ;   ;    ;;    ;  ;   ; ; 
;    ;      ;   ;  ;  ;   ;   ;;     ;  ;  ;  ; 
;    ;;     ;   ; ;   ;   ;  ;;      ;  ; ;   ; 
;    ;;    ;;    ;;   ;   ;  ;       ;   ;;   ; 
;     ;    ;     ;    ;   ;  ;       ;   ;    ; 
;     ;   ;;     ;    ;   ;  ;      ;    ;    ; 
;     ;  ;;      ;    ;   ;  ;      ;    ;    ; 
;      ;;;       ;    ;   ;   ;    ;     ;    ; 
;                              ;;;;             
(define ∪
  (λ args
    (apply union args)))
(define union
  (λ args
    (cond
      [(< (length args) 2) '()]
      [(eqv? (length args) 2) (union-helper (car args) (cadr args))]
      [else
       (apply union (union-helper (car args) (cadr args)) (cddr args))])))

(define union-helper
  (λ (fact1 fact2)
    (letrec ([helper
              (λ (fact1 fact2 res)
                (cond
                  [(null? fact1) (append res fact2)]
                  [(< (car (car fact2)) (car (car fact1)))
                   (helper fact2 fact1 res)]
                  [(eqv? (car (car fact1)) (car (car fact2)))
                   (helper (cdr fact1) (cdr fact2) (append res (list (cons (car (car fact1))
                                                                           (max (cdr (car fact1))
                                                                                (cdr (car fact2)))))))]
                  [else (helper (cdr fact1) fact2 (append res (list (car fact1))))]))])
      (helper fact1 fact2 '()))))



;                                                                         
;                                   ;                                 ;   
;                      ;            ;                                 ;   
;                      ;            ;                                 ;   
;     ;;;;;            ;            ;;                                ;;  
;    ;;                ;            ;;;                               ;;; 
;    ;                 ;          ;;;;                              ;;;;  
;   ;        ;     ;   ;    ;;;     ;;    ;         ;;;     ;;;;      ;;  
;   ;        ;     ;    ;  ;   ;    ;;    ;   ;;  ;;   ;   ;   ;;     ;;  
;    ;;      ;     ;    ;;;    ;    ;;    ;  ;         ;   ;    ;     ;;  
;     ;;;;   ;     ;    ;;     ;     ;    ; ;;         ;  ;            ;  
;        ;;  ;    ;;    ;      ;     ;    ;;;       ;; ;  ;            ;  
;   ;     ;  ;    ;;    ;     ;      ;    ;;      ;;  ;;  ;            ;  
;   ;     ;  ;   ;;;    ;    ;       ;     ;      ;   ;;  ;     ;      ;  
;   ;    ;   ;  ;  ;    ;   ;        ;     ;      ;  ; ;   ;   ;       ;  
;    ;;;;    ;  ;  ;     ;;;         ;     ;      ;;;  ;    ;;;        ;  
;             ;;   ;                                                      
(define //
  (λ (fact1 fact2)
    (subtract fact1 fact2)))
(define subtract
  (λ (fact1 fact2)
    (letrec ([helper
              (λ (fact1 fact2 res)
                (cond
                  [(null? fact1) res]
                  [else (let* ([fact1-a (car (car fact1))]
                               [fact1-d (cdr (car fact1))]
                               [v (contains-v fact2 fact1-a)]
                               [d-v (- fact1-d v)])
                          (if (> d-v 0)
                              (helper (cdr fact1) fact2 (append res (list (cons fact1-a d-v))))
                              (helper (cdr fact1) fact2 res)))]))])
      (helper fact1 fact2 '()))))


                                                                       
;                                 ;           ;                           
;                                 ;           ;                           
;    ;;;;;;;                      ;     ;     ;     ;                     
;   ;;;    ;;                     ;;          ;;                          
;   ;;      ;                     ;;;         ;;;                         
;    ;      ;                   ;;;;        ;;;;                  ;       
;    ;     ;;    ;;;    ;         ;;    ;     ;;    ;      ;;;;   ;   ;;  
;    ;     ;   ;;   ;   ;   ;;    ;;    ;     ;;    ;    ;;    ;  ;   ; ; 
;    ;   ;;         ;   ;  ;      ;;    ;     ;;    ;   ;;     ;  ;  ;  ; 
;    ;;;;           ;   ; ;;       ;    ;      ;    ;  ;;      ;  ; ;   ; 
;    ;           ;; ;   ;;;        ;    ;      ;    ;  ;       ;   ;;   ; 
;    ;         ;;  ;;   ;;         ;    ;      ;    ;  ;       ;   ;    ; 
;    ;;        ;   ;;    ;         ;    ;      ;    ;  ;      ;    ;    ; 
;    ;;        ;  ; ;    ;         ;    ;      ;    ;  ;      ;    ;    ; 
;    ;;        ;;;  ;    ;         ;    ;      ;    ;   ;    ;     ;    ; 
;    ;;                                                  ;;;;             
(define partition?
  (λ facts
    (let* ([fact (car facts)]
           [parts (cdr facts)]
           [add-parts (apply add parts)])
      (equal? fact add-parts))))

                           
;                       ;          ; 
;                       ;          ; 
;                       ;          ; 
;                       ;          ; 
;         ;             ;          ; 
;        ;;             ;          ; 
;        ; ;            ;          ; 
;       ;  ;       ;;;  ;     ;;;  ; 
;       ;  ;      ;  ;; ;    ;  ;; ; 
;      ;   ;     ;     ;;   ;     ;; 
;      ;;;;;;   ;       ;  ;       ; 
;     ;     ;   ;       ;  ;       ; 
;     ;     ;   ;      ;;  ;      ;; 
;    ;      ;   ;     ;;;  ;     ;;; 
;    ;      ;   ;;   ;; ;  ;;   ;; ; 
;   ;;            ;;;   ;    ;;;   ; 
;   ;                   ;          ;
(define ++
  (λ args
    (apply add args)))
(define add
  (λ args
    (cond
      [(< (length args) 2) '()]
      [(equal? (length args) 2) (add-helper (car args) (cadr args))]
      [else
       (apply add (add-helper (car args) (cadr args)) (cddr args))])))

(define add-helper
  (λ (fact1 fact2)
    (cond
      [(null? fact1) fact2]
      [(null? fact2) fact1]
      [(< (caar fact2) (caar fact1)) (add-helper fact2 fact1)]
      [(equal? (caar fact1) (caar fact2))
       (append (list (cons (caar fact1) (+ (cdar fact1) (cdar fact2))))
               (add-helper (cdr fact1) (cdr fact2)))]
      [else (append (list (car fact1))
                    (add-helper (cdr fact1) fact2))])))