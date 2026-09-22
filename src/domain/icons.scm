(require (prefix-in catalog. "icons/catalog.scm"))

(provide glyph-for)

; Grove reads the icon catalog `eza` ships, so a File tree row and an `eza`
; listing name the same file with the same glyph. Lookup follows `eza`'s own
; order: a directory answers by name, a file by exact filename, then by
; lowercased extension, and otherwise by a fallback.
(define (entries->hash entries)
  (let loop ([remaining entries] [result (hash)])
    (if
      (null? remaining)
      result
      (loop
        (cdr remaining)
        (hash-insert
          result
          (car (car remaining))
          (car (cdr (car remaining))))))))

(define DIRECTORIES (entries->hash catalog.directory-entries))
(define FILENAMES (entries->hash catalog.filename-entries))
(define EXTENSIONS (entries->hash catalog.extension-entries))
(define FALLBACKS (entries->hash catalog.fallback-entries))

(define (fallback name)
  (hash-ref FALLBACKS name))

; `eza` lowercases an extension before matching it, while a filename matches
; exactly. Grove keeps both rules.
(define (extension-of label)
  (let loop ([index (- (string-length label) 1)])
    (cond
      [(< index 0) #f]
      [(char=? (string-ref label index) #\.)
        (string-downcase (substring label (+ index 1) (string-length label)))]
      [else (loop (- index 1))])))

(define (file-glyph label)
  (define named (hash-try-get FILENAMES label))
  (define extension (and (not named) (extension-of label)))
  (cond
    [named named]
    [(not extension) (fallback "file-without-extension")]
    [else
      (or
        (hash-try-get EXTENSIONS extension)
        (fallback "file"))]))

(define (directory-glyph label expanded?)
  (or
    (hash-try-get DIRECTORIES label)
    (fallback (if expanded? "expanded-directory" "directory"))))

(define (glyph-for label kind expanded?)
  (cond
    [(equal? kind 'directory) (directory-glyph label expanded?)]
    [(equal? kind 'file) (file-glyph label)]
    [else (error "invalid icon kind")]))
