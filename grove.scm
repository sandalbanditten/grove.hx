(require "helix/components.scm")
(require (prefix-in helix. "src/adapters/helix.scm"))

(provide grove-theme grove-start! grove-focus! grove-visibility-toggle!)

(struct grove-theme-value (sources))

(define (grove-theme #:pane-background [pane-background #f]
         #:visible-row
         [visible-row #f]
         #:pinned-ancestor-row
         [pinned-ancestor-row #f]
         #:cursor
         [cursor #f]
         #:active-file-background
         [active-file-background #f]
         #:guides-foreground
         [guides-foreground #f]
         #:active-file-mark-foreground
         [active-file-mark-foreground #f]
         #:rail
         [rail #f]
         #:filesystem-error-foreground
         [filesystem-error-foreground #f]
         #:git-conflict-foreground
         [git-conflict-foreground #f]
         #:git-deleted-foreground
         [git-deleted-foreground #f]
         #:git-modified-foreground
         [git-modified-foreground #f]
         #:git-created-foreground
         [git-created-foreground #f]
         #:unsaved-mark-foreground
         [unsaved-mark-foreground #f])
  (grove-theme-value
    (list
      (cons 'pane-background pane-background)
      (cons 'visible-row visible-row)
      (cons 'pinned-ancestor-row pinned-ancestor-row)
      (cons 'cursor cursor)
      (cons 'active-file-background active-file-background)
      (cons 'guides-foreground guides-foreground)
      (cons 'active-file-mark-foreground active-file-mark-foreground)
      (cons 'rail rail)
      (cons 'filesystem-error-foreground filesystem-error-foreground)
      (cons 'git-conflict-foreground git-conflict-foreground)
      (cons 'git-deleted-foreground git-deleted-foreground)
      (cons 'git-modified-foreground git-modified-foreground)
      (cons 'git-created-foreground git-created-foreground)
      (cons 'unsaved-mark-foreground unsaved-mark-foreground))))

(define (valid-theme-source? source)
  (or
    (not source)
    (and (string? source) (> (string-length source) 0))
    (Style? source)))

(define (valid-theme-sources? sources)
  (or
    (null? sources)
    (and
      (valid-theme-source? (cdr (car sources)))
      (valid-theme-sources? (cdr sources)))))

; `fit` starts Grove at its Natural width; an integer starts it there instead.
(define (valid-width? value)
  (or
    (equal? value 'fit)
    (and (integer? value) (>= value 16) (<= value 64))))

(define (fit-width? value)
  (equal? value 'fit))

(define (start-width value)
  (if (fit-width? value) 32 value))

(define (valid-ls-colors? value)
  (or
    (not value)
    (equal? value 'environment)
    (string? value)))

(define (validate-settings side
         width
         icons?
         guides?
         visibility
         theme
         ls-colors)
  (unless (or (equal? side 'left) (equal? side 'right))
    (error "invalid Grove side"))
  (unless (valid-width? width)
    (error "invalid Grove width"))
  (unless (boolean? icons?)
    (error "Grove icons must be a boolean"))
  (unless (boolean? guides?)
    (error "Grove guides must be a boolean"))
  (unless (member visibility '(always focused))
    (error "invalid Grove visibility"))
  (unless (grove-theme-value? theme)
    (error "invalid Grove theme"))
  (unless (valid-theme-sources? (grove-theme-value-sources theme))
    (error "invalid Grove theme source"))
  (unless (valid-ls-colors? ls-colors)
    (error "invalid Grove LS_COLORS")))

(define (grove-start! #:icons [icons? #t]
         #:guides
         [guides? #t]
         #:visibility
         [visibility 'always]
         #:theme
         [theme (grove-theme)]
         #:side
         [side 'left]
         #:width
         [width 32]
         #:ls-colors
         [ls-colors #f])
  (validate-settings side width icons? guides? visibility theme ls-colors)
  (helix.start!
    side
    (start-width width)
    icons?
    guides?
    visibility
    (grove-theme-value-sources theme)
    ls-colors
    (fit-width? width)))

;;@doc
;;Focus Grove.
(define (grove-focus!)
  (helix.focus!))

;;@doc
;;Toggle Grove Visibility between always and focused.
(define (grove-visibility-toggle!)
  (helix.visibility-toggle!))
