(require "helix/components.scm")
(require (prefix-in palette. "../../domain/palette.scm"))

(provide resolve entry-color)

; Keep this struct-to-color conversion direct. ADR 0001 covers Steel JIT
; corruption.
(define (entry-color color)
  (cond
    [(palette.rgb-color? color)
      (Color/rgb
        (palette.rgb-color-red color)
        (palette.rgb-color-green color)
        (palette.rgb-color-blue color))]
    [(palette.indexed-color? color)
      (Color/Indexed (palette.indexed-color-index color))]
    [else #f]))

(define (resolve-color sources role default-scopes property fallback)
  (define source (cdr (assoc role sources)))
  (define candidates
    (if
      source
      (list (if (string? source) (theme-scope-ref source) source))
      (map theme-scope-ref default-scopes)))
  (define candidate (findf property candidates))
  (or (and candidate (property candidate)) fallback))

(define (resolve sources icons? guides?)
  (define (background role default-scopes fallback)
    (resolve-color sources role default-scopes style->bg fallback))
  (define (foreground role default-scopes fallback)
    (resolve-color sources role default-scopes style->fg fallback))
  (define pane-background
    (background 'pane-background '("ui.background") Color/Reset))
  (define visible-foreground
    (foreground 'visible-row '("ui.text") Color/Reset))
  (define visible-background
    (background 'visible-row '("ui.text") pane-background))
  ; A Git mark is a gutter mark, so it reads Helix's own gutter keys first.
  (define minus-scopes '("diff.minus.gutter" "diff.minus"))
  (define delta-scopes '("diff.delta.gutter" "diff.delta"))
  (define plus-scopes '("diff.plus.gutter" "diff.plus"))
  (define (row role default-scopes)
    (cons
      (background role default-scopes visible-background)
      (foreground role default-scopes visible-foreground)))

  (hash
    'pane-background pane-background
    'visible-row (cons visible-background visible-foreground)
    'pinned-ancestor-row (row 'pinned-ancestor-row '("ui.virtual.ruler"))
    'cursor (row 'cursor '("ui.text.focus"))
    'active-file
    (cons
      (background
        'active-file-background
        (list "ui.bufferline.active" "ui.statusline.active")
        visible-background)
      visible-foreground)
    'guides-foreground
    (and
      guides?
      (foreground
        'guides-foreground
        '("ui.virtual.indent-guide" "ui.virtual.whitespace")
        Color/Gray))
    'active-file-mark-foreground
    (foreground 'active-file-mark-foreground '("info") #f)
    'rail-track (background 'rail '("ui.menu.scroll") Color/Reset)
    'rail-thumb (foreground 'rail '("ui.menu.scroll") Color/Reset)
    'filesystem-error-foreground
    (foreground
      'filesystem-error-foreground
      '("error")
      Color/LightRed)
    'conflict (foreground 'git-conflict-foreground '("error") Color/Magenta)
    'deleted (foreground 'git-deleted-foreground minus-scopes Color/Red)
    'modified (foreground 'git-modified-foreground delta-scopes Color/Yellow)
    'created (foreground 'git-created-foreground plus-scopes Color/Green)
    'unsaved-mark-foreground
    (foreground 'unsaved-mark-foreground '("info") Color/Cyan)
    'icons? icons?))
