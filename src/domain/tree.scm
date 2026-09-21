(require (prefix-in path. "path.scm"))
(require (prefix-in natural. "natural.scm"))

(provide entry entry-id entry-kind
  build
  unreadable-root
  find
  index-of
  file-kind?
  directory-kind?
  expandable-kind?
  expandable?)

(struct entry (id kind))

(define (file-kind? kind)
  (and (member kind '(file file-link)) #t))

(define (directory-kind? kind)
  (and
    (member kind '(directory unreadable-directory directory-link))
    #t))

(define (expandable-kind? kind)
  (and (member kind '(directory unreadable-directory)) #t))

(define (expandable? entry)
  (and
    (not (path.root-id? (entry-id entry)))
    (expandable-kind? (entry-kind entry))))

(define (entry-rank entry final?)
  (if
    (not final?)
    0
    (cond
      [(directory-kind? (entry-kind entry))
        0]
      [(file-kind? (entry-kind entry)) 1]
      [else 2])))

(define (ordered-before? left right)
  (let loop ([left-path (split-many (entry-id left) "/")]
             [right-path (split-many (entry-id right) "/")])
    (cond
      [(null? left-path) (pair? right-path)]
      [(null? right-path) #f]
      [(string=? (car left-path) (car right-path))
        (loop (cdr left-path) (cdr right-path))]
      [else
        (define left-rank (entry-rank left (null? (cdr left-path))))
        (define right-rank (entry-rank right (null? (cdr right-path))))
        (cond
          [(< left-rank right-rank) #t]
          [(> left-rank right-rank) #f]
          [else
            (natural.before? (car left-path) (car right-path))])])))

; ADR 0013: Steel's sort turns quadratic on the nearly ordered input a
; directory listing gives, so Grove merges its own runs instead.
(define (reversed-onto reversed tail)
  (if
    (null? reversed)
    tail
    (reversed-onto (cdr reversed) (cons (car reversed) tail))))

(define (merged left right result)
  (cond
    [(null? left) (reversed-onto result right)]
    [(null? right) (reversed-onto result left)]
    [(ordered-before? (car right) (car left))
      (merged left (cdr right) (cons (car right) result))]
    [else
      (merged (cdr left) right (cons (car left) result))]))

; An already ordered listing becomes one run, so the common case stays linear.
(define (ascending-run entries)
  (let loop ([remaining (cdr entries)] [run (list (car entries))])
    (if
      (and
        (pair? remaining)
        (not (ordered-before? (car remaining) (car run))))
      (loop (cdr remaining) (cons (car remaining) run))
      (cons (reverse run) remaining))))

(define (runs-of entries)
  (let loop ([remaining entries] [result '()])
    (if
      (null? remaining)
      (reverse result)
      (let ([split (ascending-run remaining)])
        (loop (cdr split) (cons (car split) result))))))

(define (merge-pass runs result)
  (cond
    [(null? runs) (reverse result)]
    [(null? (cdr runs)) (reverse (cons (car runs) result))]
    [else
      (merge-pass
        (cdr (cdr runs))
        (cons (merged (car runs) (car (cdr runs)) '()) result))]))

(define (merge-runs runs)
  (if
    (null? (cdr runs))
    (car runs)
    (merge-runs (merge-pass runs '()))))

(define (ordered entries)
  (if
    (null? entries)
    '()
    (merge-runs (runs-of entries))))

(define (build entries)
  (cons
    (entry path.root-id 'directory)
    (ordered entries)))

(define (unreadable-root)
  (list
    (entry path.root-id 'unreadable-directory)))

(define (find file-tree id)
  (findf
    (lambda (entry) (string=? id (entry-id entry)))
    file-tree))

(define (index-of entries id)
  (let loop ([remaining entries] [ordinal 0])
    (and
      (pair? remaining)
      (if
        (string=? id (entry-id (car remaining)))
        ordinal
        (loop (cdr remaining) (+ ordinal 1))))))
