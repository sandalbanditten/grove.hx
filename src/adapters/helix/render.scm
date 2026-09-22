(require "helix/components.scm")
(require (prefix-in row. "../../domain/row.scm"))
(require (prefix-in tree. "../../domain/tree.scm"))
(require (prefix-in path. "../../domain/path.scm"))
(require (prefix-in layout. "../../domain/layout.scm"))
(require (prefix-in palette. "../../domain/palette.scm"))
(require (prefix-in theme. "theme.scm"))
(require (prefix-in icons. "../../domain/icons.scm"))

(provide draw!)

(struct run (text style))

(define (replace-control-characters text)
  (list->string
    (map (lambda (character)
          (define code (char->integer character))
          (if (or (< code 32) (= code 127)) #\? character))
      (string->list text))))

(define (error-icon-for-kind kind)
  (cond
    [(equal? kind 'unreadable-directory) "󰷌"]
    [(equal? kind 'broken-link) "󰌺"]
    [else #f]))

; Guides draw what `eza --tree` draws. Every ancestor level takes four
; columns: a lane while that ancestor still has siblings to come, blanks once
; its subtree is finished. The row's own Branch then takes three, and its last
; column carries the expansion control, the Active file mark, or a plain stem.
(define (lane-text continues? guides)
  (cond
    [(not guides) "    "]
    [continues? "│   "]
    [else "    "]))

(define (lane-runs entry current-facts guides guides-style)
  (map
    (lambda (continues?) (run (lane-text continues? guides) guides-style))
    (row.lanes current-facts entry)))

(define (branch-text last? guides)
  (cond
    [(not guides) "  "]
    [last? "└─"]
    [else "├─"]))

(define (branch-tip-runs entry
         current-facts
         guides
         guides-style
         active-file-style)
  (cond
    [(tree.expandable? entry)
      (list
        (run
          (if (row.expanded? current-facts entry) "▾" "▸")
          guides-style))]
    [(row.active-file? current-facts entry)
      (list (run "*" active-file-style))]
    [else (list (run (if guides "─" " ") guides-style))]))

(define (row-colors-for slot current-facts current-theme)
  (define entry (layout.slot-entry slot))
  (cond
    [(row.cursor? current-facts entry)
      (hash-ref current-theme 'cursor)]
    [(layout.slot-pinned? slot)
      (hash-ref current-theme 'pinned-ancestor-row)]
    [(row.active-file? current-facts entry)
      (hash-ref current-theme 'active-file)]
    [else (hash-ref current-theme 'visible-row)]))

; Helix marks a changed hunk with a bar in its diff gutter and a removal with
; the cell's top edge. Grove reads the same shapes so a Git status stays out of
; the entry label.
(define (git-mark-glyph status)
  (if (equal? status 'deleted) "▔" "▍"))

(define (git-mark-run status current-theme base-style)
  (define foreground
    (and status (hash-try-get current-theme status)))
  (if
    foreground
    (run (git-mark-glyph status) (style-fg base-style foreground))
    (run " " base-style)))

(define (row-leading-runs entry current-facts current-theme base-style)
  (define guides
    (hash-ref current-theme 'guides-foreground))
  (define guides-style
    (if guides (style-fg base-style guides) base-style))
  (define active-file-foreground
    (hash-ref current-theme 'active-file-mark-foreground))
  (define active-file-style
    (if
      active-file-foreground
      (style-fg base-style active-file-foreground)
      base-style))
  (define marks
    (list
      (git-mark-run
        (row.git-status current-facts entry)
        current-theme
        base-style)
      (run (if (row.cursor? current-facts entry) ">" " ") base-style)))
  (if
    (path.root-id? (tree.entry-id entry))
    marks
    (append
      marks
      (lane-runs entry current-facts guides guides-style)
      (list
        (run
          (branch-text (row.last-sibling? current-facts entry) guides)
          guides-style))
      (branch-tip-runs
        entry
        current-facts
        guides
        guides-style
        active-file-style))))

(define (fit-runs source-runs width base-style)
  (let loop ([remaining source-runs] [left width] [result '()])
    (cond
      [(= left 0) (reverse result)]
      [(null? remaining)
        (reverse (cons (run (make-string left #\space) base-style) result))]
      [else
        (define current (car remaining))
        (define text (run-text current))
        (define text-length (string-length text))
        (cond
          [(or
              (< text-length left)
              (and (= text-length left) (null? (cdr remaining))))
            (loop
              (cdr remaining)
              (- left text-length)
              (if (= text-length 0) result (cons current result)))]
          [else
            (reverse
              (cons
                (run
                  (if
                    (= left 1)
                    "…"
                    (string-append (substring text 0 (- left 1)) "…"))
                  (run-style current))
                result))])])))

; `eza` paints an icon with the file name's own color and drops its modifiers,
; so a glyph never carries bold or a dimmed Ignored label. Grove does the same
; with the foreground it resolved for the label.
(define (icon-glyph-for entry error-icon current-facts)
  (define kind (tree.entry-kind entry))
  (cond
    [error-icon error-icon]
    [(path.root-id? (tree.entry-id entry)) "󰙅"]
    [(tree.directory-kind? kind)
      (icons.glyph-for
        (row.label current-facts entry)
        'directory
        (row.expanded? current-facts entry))]
    [else
      (icons.glyph-for (row.label current-facts entry) 'file #f)]))

(define (icon-area-runs
         entry
         error-icon
         current-facts
         current-theme
         base-style
         label-style)
  (define root? (path.root-id? (tree.entry-id entry)))
  (define icon-run
    (and
      (hash-ref current-theme 'icons?)
      (run (icon-glyph-for entry error-icon current-facts) label-style)))
  (cond
    [(and icon-run root?) (list icon-run (run " " base-style))]
    [icon-run
      (list (run " " base-style) icon-run (run " " base-style))]
    [root? '()]
    [else (list (run " " base-style))]))

; Grove applies only the modifiers it can compose over a resolved row
; background. ADR 0010 keeps that background intact, so a reversing or hiding
; modifier is dropped rather than allowed to replace it. Steel exposes no
; underline style to construct, so underline is dropped too.
(define (with-modifier current-style modifier)
  (cond
    [(equal? modifier 'bold) (style-with-bold current-style)]
    [(equal? modifier 'dim) (style-with-dim current-style)]
    [(equal? modifier 'italic) (style-with-italics current-style)]
    [else current-style]))

(define (with-modifiers current-style modifiers)
  (if
    (null? modifiers)
    current-style
    (with-modifiers
      (with-modifier current-style (car modifiers))
      (cdr modifiers))))

(define (row-runs slot width current-facts current-theme base-style)
  (define entry (layout.slot-entry slot))
  (define body-width (max 0 (- width 1)))
  (define error-icon (error-icon-for-kind (tree.entry-kind entry)))
  ; Ignored has no Git mark and dims the label instead.
  (define git-status (row.git-status current-facts entry))
  (define entry-appearance (row.appearance current-facts entry))
  (define label-foreground
    (or
      (and
        error-icon
        (hash-ref current-theme 'filesystem-error-foreground))
      (and
        entry-appearance
        (theme.entry-color
          (palette.appearance-foreground entry-appearance)))))
  (define label-base
    (if
      label-foreground
      (style-fg base-style label-foreground)
      base-style))
  ; Entry palette modifiers say what kind of entry this is, so they survive a
  ; status that replaces the foreground.
  (define label-styled
    (if
      entry-appearance
      (with-modifiers
        label-base
        (palette.appearance-modifiers entry-appearance))
      label-base))
  (define label-final
    (if
      (equal? git-status 'ignored)
      (style-with-dim label-styled)
      label-styled))
  (define unsaved-status (row.unsaved-status current-facts entry))
  (define body
    (fit-runs
      (append
        (row-leading-runs entry current-facts current-theme base-style)
        (icon-area-runs
          entry
          error-icon
          current-facts
          current-theme
          base-style
          label-base)
        (list
          (run
            (replace-control-characters (row.label current-facts entry))
            label-final)))
      body-width
      base-style))
  (if
    (= width 0)
    body
    (append
      body
      (list
        (run
          (if unsaved-status "+" " ")
          (if
            unsaved-status
            (style-fg
              base-style
              (hash-ref current-theme 'unsaved-mark-foreground))
            base-style))))))

(define (rail-glyph-for thumb? side)
  (if
    thumb?
    (if (equal? side 'left) "▐" "▌")
    (if (equal? side 'left) "▕" "▏")))

(define (content-x current-layout)
  (if
    (equal? (layout.side current-layout) 'right)
    (+ (layout.x current-layout) 1)
    (layout.x current-layout)))

(define (draw-runs! frame runs column row)
  (unless (null? runs)
    (define current (car runs))
    (define text (run-text current))
    (frame-set-string!
      frame column row text (run-style current))
    (draw-runs!
      frame
      (cdr runs)
      (+ column (string-length text))
      row)))

(define (draw-line! frame slot current-layout row current-facts current-theme)
  (define content-width (- (layout.width current-layout) 1))
  (define side (layout.side current-layout))
  (define thumb?
    (integer? (layout.rail-thumb-offset current-layout row)))
  (define appearance
    (and slot (row-colors-for slot current-facts current-theme)))
  (define line-background
    (if
      appearance
      (car appearance)
      (hash-ref current-theme 'pane-background)))
  (define base-style
    (and
      appearance
      (style-fg (style) (cdr appearance))))
  (buffer/clear-with
    frame
    (area (content-x current-layout) row content-width 1)
    (style-bg (style) line-background))
  (when slot
    (draw-runs!
      frame
      (row-runs slot content-width current-facts current-theme base-style)
      (content-x current-layout)
      row))
  (frame-set-string!
    frame
    (layout.rail-x current-layout)
    row
    (rail-glyph-for thumb? side)
    (style-bg
      (style-fg
        (style)
        (if
          thumb?
          (hash-ref current-theme 'rail-thumb)
          (hash-ref current-theme 'rail-track)))
      (hash-ref current-theme 'pane-background))))

(define (draw! frame current-layout current-facts current-theme)
  (let loop ([offset 0]
             [remaining (layout.pane-slots current-layout)])
    (unless (= offset (layout.height current-layout))
      (draw-line!
        frame
        (and (pair? remaining) (car remaining))
        current-layout
        (+ (layout.y current-layout) offset)
        current-facts
        current-theme)
      (loop
        (+ offset 1)
        (if (pair? remaining) (cdr remaining) '())))))
