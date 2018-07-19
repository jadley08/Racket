#lang racket/base

(require racket/match
         racket/list
         define-with-spec
         rackunit)

;; * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;; Assignment "lang2b"
;; due 30 Jan by 3pm
;; * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

(define Id? symbol?)


(define/spec (reserved-symbol? x)
  (-> symbol? boolean?)
  (and (member x '(λ zero add1 which-Nat iter-Nat rec-Nat)) #t))

(define (var? x)
  (and (symbol? x)
       (not (reserved-symbol? x))))

;; a predicate for Exprs
;; Expr ::= Id | (λ (Id) Expr) | (Expr Expr) | zero | (add1 Expr) | (rec-Nat Expr Expr Expr) | (the Type Expr)
(define (Expr? e)
  (match e
    ['zero #t]
    [`(add1 ,e) (Expr? e)]
    [(? Id? x) (not (reserved-symbol? x))]
    [`(rec-Nat ,tgt ,base ,step)
     (and (Expr? tgt)
          (Expr? base)
          (Expr? step))]
    [`(λ (,x) ,body)
     (and (Id? x)
          (not (reserved-symbol? x))
          (Expr? body))]
    [`(,rator ,rand)
     (and (Expr? rator)
          (Expr? rand))]
    [`(the ,τ ,e)
     (and (Type? τ)
          (Expr? e))]
    [_ #f]))





;; list of id (List Id)
(define ListId?
  (λ (ls)
    (and (list? ls)
         (andmap (λ (entry) (Id? entry))
                 ls))))

;; tests for ListId?
(check-equal?
 (ListId? (list 'x 'y 'z 'w))
 #t)


;; NormalExpr ::= NeutralExpr | (λ (Id) NormalExpr) | zero | (add1 Expr)
(define NormalExpr?
  (λ (x) (match x
           [`,x #:when (NeutralExpr? x) #t]
           [`(λ ,listId ,n-exp)
            (and (ListId? listId)
                 (NormalExpr? n-exp))]
           ['zero #t]
           [`(add1 ,n) (NormalExpr? n)]
           [_ #f])))

;; NeutralExpr ::= Id | (NeutralExpr NormalExpr) | zero | (add1 Expr) | (rec-Nat NeutralExpr NormalExpr NormalExpr)
(define NeutralExpr?
  (λ (x) (or (Id? x)
             (match x
               [(? Id? x) (not (reserved-symbol? x))]
               [`(,rator ,rand) (and (NeutralExpr? rator)
                                     (NormalExpr? rand))]
               ['zero #t]
               [`(add1 ,y) (NeutralExpr? y)]
               [`(rec-Nat ,tgt ,base ,step)
                (and (NeutralExpr? tgt)
                     (NormalExpr? base)
                     (NormalExpr? step))]
               [`(,neutral-exp ,normal-exp)
                (and (NeutralExpr? neutral-exp)
                     (NormalExpr? normal-exp))]
               [_ #f]))))



;; a closure (i.e. function value)
(struct/spec CLOSURE ([ρ ValueEnv?]
                      [id Id?]
                      [body Expr?]))

;; ρ is a ValueEnv?
;; id is an Id?
;; body is an Expr?
;; NOTE: when we define a struct with struct/spec,
;; it defines functions that access the respective
;; fields, in this case:
;; - CLOSURE-ρ
;; - CLOSURE-id
;; - CLOSURE-body
;; along with a constructor and predicate:
;; - CLOSURE
;; - CLOSURE?


(struct/spec ZERO ())
(struct/spec ADD1 ([body (either ZERO?
                                 ADD1?
                                 N-Val?)]))

(define NUMBER? (λ (n) (or (ADD1? n)
                           (ZERO? n))))

;; a Value is a CLOSURE
(define Value? (λ (x)
                 (or (NUMBER? x)
                     (CLOSURE? x)
                     (N-Val? x))))



;; a ValueEnv is a (listof (list Id? Value?))
(define (ValueEnv? ρ)
  (and (list? ρ)
       (andmap (λ (entry) (and (= 2 (length entry))
                               (Id? (first entry))
                               (Value? (second entry))))
               ρ)))




;; a Neutral identifier -- an intermediate
;; part of the NbE process
(struct/spec N-ID ([name Id?]))


;; a Neutral application -- an intermediate
;; part of the NbE process
(struct/spec N-APP ([rator N-Val?]
                    [rand Value?]))

;; Neutral Nat eliminator forms
(struct/spec N-REC-NAT ([tgt N-Val?]
                        [base Value?]
                        [step Value?]))


;; Neutral terms that appear during
;; NbE conversion
(define N-Val? (λ (x) (or (N-ID? x)
                          (N-APP? x)
                          (N-REC-NAT? x))))



;; lookup the value of x in ρ
(define/spec (lookup ρ x)
  (-> ValueEnv? Id? (either Value? #f))
  (match (assoc x ρ)
    ;; this match pattern matches
    ;; when the value is the literal #f
    [#f #f]
    [`(,_ ,val) val]))

;; extend ρ with the mapping from x to v
(define/spec (extend ρ x v)
  (-> ValueEnv? Id? Value? ValueEnv?)
  (cons (list x v) ρ))



(define/spec (valof ρ e)
  (-> ValueEnv? Expr? Value?)
  (match e
    [`(the ,τ ,e) (valof ρ e)]
    [`zero (ZERO)]
    [`(add1 ,n) (ADD1 (valof ρ n))]
    [`,y #:when (and (Id? y) (not (reserved-symbol? y))) (or (lookup ρ y)
                                                             (error 'valof "unbound identifier ~v" y))]
    [`(rec-Nat ,tgt ,base ,step)
     (elim-rec-Nat (valof ρ tgt) (valof ρ base) (valof ρ step))]
    [`(λ (,x) ,body) #:when (not (reserved-symbol? x))
     (CLOSURE ρ x body)]
    [`(,rator ,rand) (elim-fun (valof ρ rator) (valof ρ rand))]))








;; predicates for types
(define/spec (Type? e)
  (-> any boolean?)
  (match e
    ['Nat #t]
    [`(-> ,t1 ,t2)
     (and (Type? t1) (Type? t2))]
    [_ #f]))


(define/spec (TypeEnv? Γ)
  (-> any boolean?)
  (and (list? Γ)
       (andmap (λ (entry) (and (= 2 (length entry))
                               (Id? (first entry))
                               (Type? (second entry))))
               Γ)))


(define/spec (extend-Γ Γ x τ)
  (-> TypeEnv? Id? Type? TypeEnv?)
  (cons (list x τ) Γ))

(define/spec (lookup-Γ Γ x)
  (-> TypeEnv? Id? (either Type? #f))
  (match (assoc x Γ)
    [#f #f]
    [`(,_ ,τ) τ]))


;check helpers

;;T-zero
;--------------
;Γ ⊢ zero <= Nat
(define/spec (check-zero Γ e τ)
  (-> TypeEnv? Expr? Type? boolean?)
  (eqv? τ 'Nat))

;;T-add1
;Γ ⊢ e <= Nat
;------------------
;Γ ⊢ (add1 e) <= Nat
(define/spec (synth-add1 Γ e)
  (-> TypeEnv? Expr? Type?)
  (match e
    [`(add1 ,b) #:when (Expr? b) (if (check Γ b 'Nat)
                                     'Nat
                                     (error "check-add1:" b "under add1 is not a Nat"))]
    [`(add1 ,b) (error "check-add1:" b "under add1 is not an expression")]
    [_ (error "check-add1-else")]))

;;TC-Abstraction (λ)
;Γ,x : A ⊢ e <= B
;------------------
;Γ ⊢ λx.e <= A -> B
(define/spec (check-λ Γ e τ)
  (-> TypeEnv? Expr? Type? boolean?)
  (match e
    [`(λ (,x) ,b) #:when (and (if (Id? x)
                                  #t
                                  (error "check-λ:" x "identifier in λ epression not an identifier"))
                              (if (Expr? b)
                                  #t
                                  (error "check-λ:" b "body in λ expression not an expression")))
                  (match τ
                    [`(-> ,τa ,τb) (check (extend-Γ Γ x τa) b τb)]
                    [_ (error "check-λ: type for λ expression is not an arrow type:" τ)])]))


;;synth helpers

;;TS-var
;---------------------
;Γ1,x : A, Γ2 ⊢ x => A
(define/spec (synth-var Γ e)
  (-> TypeEnv? Expr? Type?)
  (let ([τ (lookup-Γ Γ e)])
    (if (eqv? τ #f)
        (error "synth-var: the variable" e "is not in the environment")
        τ)))

;;TS-Ann
(define/spec (synth-the Γ e)
  (-> TypeEnv? Expr? Type?)
  (match e
    [`(the ,τ ,e) (if (check Γ e τ)
                      τ
                      (error "synth-the: in (the" τ e ")," e "is not a" τ))]))

;;TS-app
;Γ ⊢ e1 => A -> B     Γ ⊢ e2 <= A
;--------------------------------
;Γ ⊢ (e1 e2) => B
(define/spec (synth-app Γ e)
  (-> TypeEnv? Expr? Type?)
  (match e
    [`(,e1 ,e2) (let ([τ-e1-a->b (synth Γ e1)])
                  (match τ-e1-a->b
                    [`(-> ,τa ,τb) (if (check Γ e2 τa)
                                       τb
                                       (error "synth-app: the operand:" e2 "does not match the input type to operator:" e1 "with type" τ-e1-a->b))]
                    [_ (error "synth-app: operator:" e1 "has invalid type (not arrow type):" τ-e1-a->b)]))]))


;;TS-rec-Nat
;Γ ⊢ e1 => Nat
;Γ ⊢ e2 => X
;Γ ⊢ e3 <= Nat -> X -> X
;---------------------------
;Γ ⊢ (rec-Nat e1 e2 e3) => X

;redo
(define/spec (synth-rec-Nat Γ e)
  (-> TypeEnv? Expr? Type?)
  (match e
    [`(rec-Nat ,e1 ,e2 ,e3)
     (if (eqv? (synth Γ e1) 'Nat)
         (let ([τe2 (synth Γ e2)])
           (if (check Γ e3 `(-> ,'Nat (-> ,τe2 ,τe2)))
               τe2
               (error "synth-rec-Nat: base type" τe2 "does not match type of step" (synth Γ e3))))
         (error "synth-rec-Nat:" e1 "target is not a Nat"))]))


;check (introduction forms)
(define/spec (check Γ e τ)
  (-> TypeEnv? Expr? Type? boolean?)
  (match e
    [`(λ (,x) ,b) (check-λ Γ e τ)]
    ;TC-Synth
    [_ (eqv? (synth Γ e) τ)]))


;synth (elimination forms)
(define/spec (synth Γ e)
  (-> TypeEnv? Expr? Type?)
  (match e
    ['zero 'Nat]
    [`(add1 ,b) (synth-add1 Γ e)]
    ;TC-Ann
    [`(the ,τ ,e2) (synth-the Γ e)]
    [`,x #:when (Id? x)
         (synth-var Γ x)]
    [`(,e1 ,e2) (synth-app Γ e)]
    [`(rec-Nat ,e1 ,e2 ,e3) (synth-rec-Nat Γ e)]
    [_ (error "could not determine a type, synth: the expression " e "is not a synthesisable")]))





;tests for check/synth
(check-equal?
 (check '() 'zero 'Nat)
 #t)
(check-equal?
 (check '() 'zero '(-> Nat Nat))
 #f)
(check-equal?
 (check '() '(add1 zero) 'Nat)
 #t)
(check-equal?
 (check '() '(add1 (add1 zero)) 'Nat)
 #t)
(check-equal?
 (check '() '(add1 (add1 zero)) '(-> Nat Nat))
 #f)
(check-equal?
 (check '() '(λ (x) zero) '(-> Nat Nat))
 #t)
(check-equal?
 (check (list (list 'x 'Nat) (list 'y 'Nat)) '(λ (x) y) '(-> (-> Nat Nat) Nat))
 #t)
(check-equal?
 (synth (list (list 'y 'Nat)) 'y)
 'Nat)
(check-equal?
 (synth (list (list 'x '(-> Nat Nat))) 'x)
 '(-> Nat Nat))
(check-equal?
 (synth
  '()
  '(rec-Nat zero
            zero
            (λ (x)
              (λ (y)
                zero))))
 'Nat)
(check-equal?
 (synth
  '()
  '(rec-Nat (add1 (add1 zero))
            zero
            (λ (x)
              (λ (y)
                zero))))
 'Nat)
(check-equal?
 (synth
  (list (list 'x 'Nat) (list 'y 'Nat))
  '(rec-Nat (add1 (add1 zero))
             zero
             (λ (x)
               (λ (y)
                 zero))))
 'Nat)
(check-equal?
 (synth
  (list (list 'y 'Nat))
  '(rec-Nat (add1 (add1 zero))
            zero
            (λ (x)
              (λ (y)
                (add1 y)))))
 'Nat)
(check-equal?
 (synth '((id (-> Nat Nat))) '(id zero))
 'Nat)
(check-equal?
 (synth '((y Nat))
        '(the Nat y))
 'Nat)
(check-equal?
 (check '((y Nat))
        '(the Nat y)
        'Nat)
 #t)



;Nat eliminator helpers
(define/spec (elim-rec-Nat tgt base step)
  (-> Value? Value? Value? Value?)
  (cond
    [(N-Val? tgt) (N-REC-NAT tgt base step)]
    [(ZERO? tgt) base]
    [else (elim-fun (elim-fun step (ADD1-body tgt))
                    (elim-rec-Nat (ADD1-body tgt) base step))]))


;λ (function) elimination
(define/spec (elim-fun rator rand)
  (-> Value? Value? Value?)
  (match rator
    [(CLOSURE ρ id body)
     (valof (extend ρ id rand)
            body)]
    [(? N-Val?) (N-APP rator rand)]))


;;returns a version of id not in used
(define freshen
  (λ (used x)
    (cond
      [(not (member x used)) x]
      [else (freshen-helper used x 1)])))

(define freshen-helper
  (λ (used x n)
    (let ([xn (string->symbol
               (string-append
                (symbol->string x)
                (number->string n)))])
      (if (member xn used)
          (freshen-helper used x (add1 n))
          xn))))



;; reads val back as an expression
(define/spec (read-back used-names val)
  (-> ListId? (either N-Val? Value?) (either NeutralExpr? NormalExpr?))
  (match val
    [(ZERO) 'zero]
    [(ADD1 body) `(add1 ,(read-back used-names body))]
    [(N-REC-NAT tgt base step)
     `(rec-Nat ,(read-back used-names tgt) ,(read-back used-names base) ,(read-back used-names step))]
    [(CLOSURE ρ id body)
     (let ([fresh-id (freshen used-names id)])
       `(λ (,fresh-id)
          ,(read-back (cons fresh-id used-names)
                      (valof (extend ρ id (N-ID fresh-id))
                             body))))]
    [(N-ID x) x]
    [(N-APP rator rand)
     `(,(read-back used-names rator)
       ,(read-back used-names rand))]))


;; normalize an expression by evaluating
;; it and reading back the value as an Expr
(define/spec (normalize ρ e)
  (-> ValueEnv? Expr? NormalExpr?)
  (read-back '() (valof ρ e)))



;; a Define is a (define Id Expr)
(define (Define? e)
  (match e
    [`(define ,name ,body)
     (and (symbol? name)
          (not (reserved-symbol? name))
          (Expr? body))]
    [_ #f]))

;; a Program is a list of Expr or Define
;; that should end with an Expr.
(define (Program? p)
  (and (list p)
       (andmap (λ (e) (or (Expr? e) (Define? e) (Claim? e)))
               p)))

;; a Claim is a
(define/spec (Claim? e)
  (-> any boolean?)
  (match e
    [`(claim ,(? var?) ,(? Type?)) #t]
    [_ #f]))

;; takes a program and a context and returns a boolean depending on if the
;; program is well typed
;need to add a case for second last match case in valof-program to make sure no λ's???
(define/spec (check-program Γ program)
  (-> TypeEnv? Program? boolean?)
  (match program
    [`((define ,x ,e) . ,rest-of-the-program)
     (check Γ e (lookup-Γ Γ x))]
    [`(,e . ,rest-of-the-program)
     (if (synth Γ e)
         #t
         #f)]
    [_ (error "check-program:else (not a program)")]))

;; Evaluates a Program, i.e. for each (define id body),
;; evaluate body in the current value environment ρ to some value v,
;; and then proceeds to evaluate the rest of the program with value
;; environment ρ[id ↦ v]. valof-program returns the list of results
;; from evaluating top level expressions.
(define/spec (valof-program ρ program Γ)
  (-> ValueEnv? Program? TypeEnv? (listof NormalExpr?))
  (match program
    ;; extend the current type environment with the claim (id x and type of e)
    [`((claim ,x ,e) . ,rest-of-the-program) (valof-program ρ rest-of-the-program (extend-Γ Γ x e))]
    ;; this match pattern matches a cons where the
    ;; car matches the pattern `(define ,x ,e)
    ;; and the cdr can be anything (and is bound
    ;; to the identifier rest-of-the-program)
    [`((define ,x ,e) . ,rest-of-the-program)
     (if (eqv? #f (lookup-Γ Γ x))
         (error "valof-program-define: (define" x "...) does not have a claim")
         (if (check-program Γ program)
             (valof-program (extend ρ x (valof ρ e))
                            rest-of-the-program
                            Γ)
             (error "valof-program-define: the type of" x "," (synth Γ e) "does not match expected type" (lookup-Γ Γ x))))]
    ;; this match pattern is like the above one (i.e. a cons)
    ;; but only succeeds when the #:when predicate (Expr? e)
    ;; is also non-#f
    [`(,e . ,rest-of-the-program)
     #:when (Expr? e)
     (if (check-program Γ program)
         (cons (normalize ρ e)
               (valof-program ρ rest-of-the-program Γ))
         (error "valof-program:" program "is not well-typed"))]
    ['() '()]))



;; given an expression e, returns a program
;; that begins with the following definitions
;; - church-zero
;; - church-add1
;; - church-plus
;; and that ends with expression e.
;; NOTE: this allows us to write simple programs
;; that use church-numerals in them, which can be
;; useful for testing a bare-bones language like
;; the λ-calculus.
(define/spec (with-church-numerals e)
  (-> Expr? Program?)
  `((define church-zero
      (λ (f) (λ (x) x)))
    (define church-add1
      (λ (n-1) (λ (f)
                 (λ (x)
                   (f ((n-1 f) x))))))
    (define church-plus
      (λ (j)
        (λ (k) (λ (f)
                 (λ (x)
                   ((j f) ((k f) x)))))))
    ,e))


;; converts a natural number (e.g. 2) to a church
;; numeral of equal value (e.g. (λ (f) (λ (x) (f (f x)))))
(define/spec (to-church n)
  (-> exact-nonnegative-integer? Expr?)
  (cond [(zero? n) 'church-zero]
        [else
         (let ([church-of-n-1 (to-church (sub1 n))])
           `(church-add1 ,church-of-n-1))]))


;; TESTS
;; things seem to be working very slowly, work on it
;; new tests for type-checked valof-program
(check-equal?
 (valof-program
  '()
  '((claim id (-> Nat Nat))
    (define id
      (λ (x) x))
    (id (add1 zero)))
  '())
 '((add1 zero)))

(check-equal?
 (valof-program
  '()
  '(((the (-> Nat Nat) (λ (x) x))
     (add1 zero)))
  '())
 '((add1 zero)))

(check-equal?
 (valof-program
  '()
  '((claim + (-> Nat (-> Nat Nat)))
    (define + (λ (n) (λ (m) (rec-Nat n m (λ (cur-1) (λ (cur-1+m) (add1 cur-1+m)))))))
    ((+ zero) (add1 zero)))
  '())
 '((add1 zero)))

(check-equal?
 (valof-program
  '()
  '((claim + (-> Nat (-> Nat Nat)))
    (define + (λ (n) (λ (m) (rec-Nat n m (λ (cur-1) (λ (cur-1+m) (add1 cur-1+m)))))))
    ((+ (add1 (add1 zero))) (add1 zero)))
  '())
 '((add1 (add1 (add1 zero)))))

(check-equal?
 (valof-program
  '()
  '((claim + (-> Nat (-> Nat Nat)))
    (define + (λ (n) (λ (m) (rec-Nat n m (λ (cur-1) (λ (cur-1+m) (add1 cur-1+m)))))))
    (+ zero))
  '())
 '((λ (m) m)))

(check-equal?
 (valof-program
  '()
  '((claim + (-> Nat (-> Nat Nat)))
    (define + (λ (n) (λ (m) (rec-Nat n m (λ (cur-1) (λ (cur-1+m) (add1 cur-1+m)))))))
    (+ (add1 zero)))
  '())
 '((λ (m) (add1 m))))

;;error tests
#; ;work on a better error for this (or is it good?)
(valof-program
  '()
  '((claim id (-> (-> Nat Nat) Nat))
    (define id
      (λ (x) x))
    (id (add1 zero)))
  '())

#; ;(error not synthesisable)
(valof-program
 '()
 '(((λ (x) x) (add1 zero)))
 '())

#; ;(error define w/o a claim)
(valof-program
 '()
 '((define id (λ (x) x))
   (id (add1 zero)))
 '())

#; ;(error (add1 zero) is not a (-> Nat Nat)
(valof-program
 '()
 '((the (-> Nat Nat) (add1 zero)))
 '())

#; ;λ expr is not an -> type
(check-equal?
 (valof-program
  '()
  '((claim + (-> Nat Nat))
    (define + (λ (n) (λ (m) (rec-Nat n m (λ (cur-1) (λ (cur-1+m) (add1 cur-1+m)))))))
    ((+ zero) (add1 zero)))
  '())
 '((add1 zero)))

#; ;failure!
(valof-program
 '()
 '((claim + (-> Nat (-> Nat Nat)))
   (define + (λ (n) (λ (m) (rec-Nat n m (λ (cur-1) (λ (cur-1+m) (add1 cur-1+m)))))))
   (λ (z) ((+ z) zero)))
 '())