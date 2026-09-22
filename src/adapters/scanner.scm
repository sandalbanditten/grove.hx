(require (prefix-in tree. "../domain/tree.scm"))
(require (prefix-in path. "../domain/path.scm"))
(require (prefix-in expansion. "../domain/expansion.scm"))

(provide scan)

(define (metadata-at path)
  (with-handler (lambda (_) #f) (file-metadata path)))

(define (directory-entries path)
  (with-handler
    (lambda (_) #f)
    (let loop ([iterator (read-dir-iter path)] [entries '()])
      (define entry (read-dir-iter-next! iterator))
      (if entry
        (loop iterator (cons entry entries))
        entries))))

(define (symlink-kind entry)
  (define metadata (metadata-at (read-dir-entry-path entry)))
  (cond
    [(not metadata) 'broken-link]
    [(fs-metadata-is-dir? metadata) 'directory-link]
    [(fs-metadata-is-file? metadata) 'file-link]
    [else 'broken-link]))

(define (scan-entry entry parent-id expansion-value)
  (define name (read-dir-entry-file-name entry))
  (define id (path.child-id parent-id name))
  (cond
    [(string=? name ".git")
      '()]
    [(read-dir-entry-is-symlink? entry)
      (list (tree.entry id (symlink-kind entry)))]
    [(read-dir-entry-is-file? entry)
      (list (tree.entry id 'file))]
    [(read-dir-entry-is-dir? entry)
      (define expanded?
        (expansion.contains? expansion-value id))
      (define descendants
        (if
          expanded?
          (scan-directory
            (read-dir-entry-path entry)
            id
            expansion-value)
          (scan-run (read-dir-entry-path entry) id)))
      (define kind
        (if
          (and expanded? (not descendants))
          'unreadable-directory
          'directory))
      ; A collapsed directory reports no contents, so `scan-run` never turns a
      ; miss into a failure the way an expanded scan does.
      (cons
        (tree.entry id kind)
        (if descendants descendants '()))]
    [else
      '()]))

; Grove aggregates a run of single-child directories into one row, which it
; can only do while holding the run itself. A collapsed directory therefore
; reports the run below it and nothing else: one listing per step, taken only
; while a directory holds exactly one scannable entry.
(define (sole-directory entries)
  (and
    (pair? entries)
    (null? (cdr entries))
    (not (read-dir-entry-is-symlink? (car entries)))
    (read-dir-entry-is-dir? (car entries))
    (not (string=? (read-dir-entry-file-name (car entries)) ".git"))
    (car entries)))

(define (scan-run path parent-id)
  (define only (sole-directory (or (directory-entries path) '())))
  (if
    (not only)
    '()
    (let ([id (path.child-id parent-id (read-dir-entry-file-name only))])
      (cons
        (tree.entry id 'directory)
        (scan-run (read-dir-entry-path only) id)))))

(define (scan-directory path parent-id expansion-value)
  (define entries (directory-entries path))
  (and
    entries
    (let loop ([remaining entries] [result '()])
      (if
        (null? remaining)
        result
        (loop
          (cdr remaining)
          (append
            (scan-entry (car remaining) parent-id expansion-value)
            result))))))

(define (scan root expansion-value directories-first?)
  (define entries
    (scan-directory root path.root-id expansion-value))
  (if
    entries
    (tree.build entries directories-first?)
    (tree.unreadable-root)))
