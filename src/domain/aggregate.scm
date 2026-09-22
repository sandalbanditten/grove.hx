(require (prefix-in path. "path.scm"))
(require (prefix-in tree. "tree.scm"))

(provide presented)

; A directory whose only child is another directory adds nothing but a step in
; a path, so Grove presents the whole run as one row. The File tree holds one
; level past every collapsed directory for exactly this reason, so a run is
; visible before it is expanded.
(define (children-index file-tree)
  (let loop ([remaining file-tree] [result (hash)])
    (if
      (null? remaining)
      result
      (let* ([entry (car remaining)]
             [parent (path.parent-id (tree.entry-id entry))])
        (loop
          (cdr remaining)
          (if
            parent
            (hash-insert
              result
              parent
              (cons entry (or (hash-try-get result parent) '())))
            result))))))

; The Workspace root never joins a run: it names the Workspace, not a step.
(define (only-directory-child index id)
  (define children (and (not (path.root-id? id)) (hash-try-get index id)))
  (and
    (pair? children)
    (null? (cdr children))
    (equal? (tree.entry-kind (car children)) 'directory)
    (car children)))

(define (run-tail index entry)
  (define next (only-directory-child index (tree.entry-id entry)))
  (if next (run-tail index next) entry))

(define (continues-run? index entry)
  (define parent (path.parent-id (tree.entry-id entry)))
  (define only (and parent (only-directory-child index parent)))
  (and
    only
    (equal? (tree.entry-id only) (tree.entry-id entry))
    #t))

; Each run reports once, at its head, under the identity of its tail. Every
; other member is already part of that row and reports nothing.
(define (presented file-tree entries aggregate?)
  (if
    (not aggregate?)
    entries
    (let ([index (children-index file-tree)])
      (let loop ([remaining entries] [result '()])
        (if
          (null? remaining)
          (reverse result)
          (loop
            (cdr remaining)
            (if
              (continues-run? index (car remaining))
              result
              (cons (run-tail index (car remaining)) result))))))))
