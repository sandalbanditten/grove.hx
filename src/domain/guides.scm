(require (prefix-in path. "path.scm"))
(require (prefix-in tree. "tree.scm"))

(provide plan last-sibling? lanes presented-parent)

; Guides draw the shape `eza --tree` draws: one Ancestor lane for every
; ancestor a row actually shows, then the row's own Branch. An aggregated run
; hides its intermediate directories, so ancestry follows presented rows rather
; than path depth, and one plan answers that for every Visible row at once.
(struct plan-value (parents lasts))

(define (id-set entries)
  (let loop ([remaining entries] [result (hash)])
    (if
      (null? remaining)
      result
      (loop
        (cdr remaining)
        (hash-insert result (tree.entry-id (car remaining)) #t)))))

(define (nearest-presented ids id)
  (let loop ([remaining (reverse (path.ancestor-ids id))])
    (cond
      [(null? remaining) path.root-id]
      [(hash-contains? ids (car remaining)) (car remaining)]
      [else (loop (cdr remaining))])))

(define (parents-of ids entries)
  (let loop ([remaining entries] [result (hash)])
    (if
      (null? remaining)
      result
      (let ([id (tree.entry-id (car remaining))])
        (loop
          (cdr remaining)
          (hash-insert result id (nearest-presented ids id)))))))

; Walking backwards, the first row seen under a parent is the last one shown
; under it, which is what ends a sibling run.
(define (lasts-of parents entries)
  (let loop ([remaining (reverse entries)] [closed (hash)] [result (hash)])
    (if
      (null? remaining)
      result
      (let* ([id (tree.entry-id (car remaining))]
             [parent (hash-try-get parents id)]
             [ends-run? (and parent (not (hash-contains? closed parent)))])
        (loop
          (cdr remaining)
          (if parent (hash-insert closed parent #t) closed)
          (hash-insert result id (and ends-run? #t)))))))

(define (plan entries)
  (define parents (parents-of (id-set entries) entries))
  (plan-value parents (lasts-of parents entries)))

(define (last-sibling? current-plan id)
  (and (hash-try-get (plan-value-lasts current-plan) id) #t))

(define (presented-parent current-plan id)
  (or (hash-try-get (plan-value-parents current-plan) id) path.root-id))

; One lane per presented non-root ancestor, outermost first. A lane continues
; while that ancestor still has rows to come, and falls blank once its subtree
; is finished.
(define (lanes current-plan id)
  (define parents (plan-value-parents current-plan))
  (let loop ([remaining (path.ancestor-ids id)] [result '()])
    (cond
      [(null? remaining) (reverse result)]
      [(path.root-id? (car remaining)) (loop (cdr remaining) result)]
      [(not (hash-contains? parents (car remaining)))
        (loop (cdr remaining) result)]
      [else
        (loop
          (cdr remaining)
          (cons (not (last-sibling? current-plan (car remaining))) result))])))
