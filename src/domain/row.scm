(require (prefix-in tree. "tree.scm"))
(require (prefix-in git. "git.scm"))
(require (prefix-in path. "path.scm"))
(require (prefix-in expansion. "expansion.scm"))
(require (prefix-in palette. "palette.scm"))

(provide facts
  label
  natural-width
  appearance
  exact-git-status?
  git-status
  unsaved-status
  active-file?
  cursor?
  expanded?)

(struct facts
  (root git-status unsaved-ids active-id cursor expansion palette))

(define (label current-facts entry)
  (define id (tree.entry-id entry))
  (path.basename
    (if (path.root-id? id) (facts-root current-facts) id)))

(define (icon-area-width root? icons?)
  (cond
    [(not icons?) (if root? 0 1)]
    [root? 2]
    [else 3]))

; ADR 0012 keeps arithmetic within the arity Steel's JIT compiles.
(define (fixed-width id root? icons?)
  (+
    ; Cursor mark, expansion control, and Unsaved mark
    (if root? 2 3)
    ; Ancestor traces
    (* 2 (max 0 (- (path.depth id) 1)))
    (icon-area-width root? icons?)))

; Grove builds every row from the same fixed parts, so the columns one row
; needs in full are their total. Keep this in step with the Pane renderer.
(define (natural-width current-facts entry icons?)
  (define id (tree.entry-id entry))
  (+
    (fixed-width id (path.root-id? id) icons?)
    (string-length (label current-facts entry))))

; An Entry palette resolves a name by what kind of thing it is. Grove's kinds
; collapse onto the four that the format separates for a File tree, so an
; unfollowed directory link resolves as the link it is.
(define (palette-kind kind)
  (cond
    [(member kind '(directory unreadable-directory)) 'directory]
    [(member kind '(file-link directory-link)) 'link]
    [(equal? kind 'broken-link) 'orphan]
    [else 'file]))

(define (appearance current-facts entry)
  (define entry-palette (facts-palette current-facts))
  (and
    entry-palette
    (palette.appearance-for
      entry-palette
      (label current-facts entry)
      (palette-kind (tree.entry-kind entry)))))

(define (git-status current-facts entry)
  (define kind (tree.entry-kind entry))
  (and
    (not (member kind '(unreadable-directory broken-link)))
    (git.status-for
      (facts-git-status current-facts)
      (tree.entry-id entry)
      (tree.directory-kind? kind))))

; Grove aggregates a directory's Git status from everything beneath it. That
; aggregate says only that something below changed, so presentation may rank it
; below a rule that names the row itself.
(define (exact-git-status? current-facts entry)
  (and
    (git.exact-status-for
      (facts-git-status current-facts)
      (tree.entry-id entry))
    #t))

(define (unsaved-status current-facts entry)
  (define id (tree.entry-id entry))
  (define kind (tree.entry-kind entry))
  (define unsaved-ids (facts-unsaved-ids current-facts))
  (cond
    [(tree.file-kind? kind)
      (and (member id unsaved-ids) 'unsaved)]
    [(tree.directory-kind? kind)
      (and
        (findf
          (lambda (candidate) (path.id-inside? id candidate))
          unsaved-ids)
        'unsaved-ancestor)]
    [else #f]))

(define (active-file? current-facts entry)
  (equal? (facts-active-id current-facts) (tree.entry-id entry)))

(define (cursor? current-facts entry)
  (equal? (facts-cursor current-facts) (tree.entry-id entry)))

(define (expanded? current-facts entry)
  (define id (tree.entry-id entry))
  (or
    (path.root-id? id)
    (and
      (tree.expandable-kind? (tree.entry-kind entry))
      (expansion.contains? (facts-expansion current-facts) id))))
