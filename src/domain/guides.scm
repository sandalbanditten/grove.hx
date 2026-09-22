(require (prefix-in path. "path.scm"))
(require (prefix-in tree. "tree.scm"))

(provide plan last-sibling? lanes)

; Guides draw the shape `eza --tree` draws: one Ancestor lane for every
; ancestor that still has siblings below it, then the row's own Branch. Both
; ask the same question of a row -- does its sibling run end here -- so one
; backward pass answers it for every Visible row at once.
(define (plan entries)
  (let loop ([remaining (reverse entries)] [closed (hash)] [result (hash)])
    (if
      (null? remaining)
      result
      (let* ([id (tree.entry-id (car remaining))]
             [parent (path.parent-id id)]
             [ends-run? (and parent (not (hash-contains? closed parent)))])
        (loop
          (cdr remaining)
          (if parent (hash-insert closed parent #t) closed)
          (hash-insert result id (and ends-run? #t)))))))

(define (last-sibling? current-plan id)
  (and (hash-try-get current-plan id) #t))

; One lane per non-root ancestor, outermost first. A lane continues while that
; ancestor still has siblings to come; otherwise its column falls blank.
(define (lanes current-plan id)
  (let loop ([remaining (path.ancestor-ids id)] [result '()])
    (cond
      [(null? remaining) (reverse result)]
      [(path.root-id? (car remaining)) (loop (cdr remaining) result)]
      [else
        (loop
          (cdr remaining)
          (cons (not (last-sibling? current-plan (car remaining))) result))])))
