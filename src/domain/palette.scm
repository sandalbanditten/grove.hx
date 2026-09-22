(provide parse
  appearance-for
  appearance-foreground
  appearance-modifiers
  rgb-color?
  rgb-color-red
  rgb-color-green
  rgb-color-blue
  indexed-color?
  indexed-color-index)

; An Entry palette is the `LS_COLORS` ruleset that `vivid`, `eza`, and GNU `ls`
; share. It keeps that format's own vocabulary; callers ask in Grove's terms.
; Type rules answer by key, single-segment extensions by direct index, and
; every other pattern by the last character its suffix can match.
(struct palette-value (types extensions scanned))
(struct appearance-value (foreground modifiers))
(struct rgb-color (red green blue))
(struct indexed-color (index))

(define appearance-foreground appearance-value-foreground)
(define appearance-modifiers appearance-value-modifiers)

(define (type-key kind)
  (cond
    [(equal? kind 'directory) "di"]
    [(equal? kind 'link) "ln"]
    [(equal? kind 'orphan) "or"]
    [(equal? kind 'file) "fi"]
    [else (error "invalid Entry palette kind")]))

(define (modifier-for code)
  (cond
    [(= code 1) 'bold]
    [(= code 2) 'dim]
    [(= code 3) 'italic]
    [(= code 4) 'underline]
    [(= code 5) 'slow-blink]
    [(= code 6) 'rapid-blink]
    [(= code 7) 'reversed]
    [(= code 8) 'hidden]
    [(= code 9) 'crossed-out]
    [else #f]))

; SGR 30-37 name the first eight palette slots and 90-97 their bright halves.
(define (basic-index code)
  (cond
    [(and (>= code 30) (<= code 37)) (- code 30)]
    [(and (>= code 90) (<= code 97)) (- code 82)]
    [else #f]))

(define (byte-at tokens index)
  (define token (try-list-ref tokens index))
  (define value (and (string? token) (string->number token)))
  (and (integer? value) (>= value 0) (<= value 255) value))

; `38` and `48` introduce one of two argument runs: `5;index` or
; `2;red;green;blue`. Both are consumed whole, so a background never leaks into
; the modifier list.
(define (extended-length tokens)
  (define selector (try-list-ref tokens 0))
  (cond
    [(equal? selector "5") 2]
    [(equal? selector "2") 4]
    [else 0]))

(define (extended-color tokens)
  (define selector (try-list-ref tokens 0))
  (cond
    [(equal? selector "5")
      (let ([index (byte-at tokens 1)])
        (and index (indexed-color index)))]
    [(equal? selector "2")
      (let ([red (byte-at tokens 1)]
            [green (byte-at tokens 2)]
            [blue (byte-at tokens 3)])
        (and red green blue (rgb-color red green blue)))]
    [else #f]))

(define (walk-codes tokens foreground modifiers)
  (if
    (null? tokens)
    (appearance-value foreground (reverse modifiers))
    (let* ([rest (cdr tokens)]
           [code (string->number (car tokens))]
           [index (and (integer? code) (basic-index code))]
           [modifier (and (integer? code) (modifier-for code))])
      (cond
        [(not (integer? code)) (walk-codes rest foreground modifiers)]
        [(= code 0) (walk-codes rest #f '())]
        [(= code 38)
          (walk-codes
            (list-drop rest (extended-length rest))
            (or (extended-color rest) foreground)
            modifiers)]
        [(= code 48)
          (walk-codes
            (list-drop rest (extended-length rest))
            foreground
            modifiers)]
        [(= code 39) (walk-codes rest #f modifiers)]
        [index (walk-codes rest (indexed-color index) modifiers)]
        [modifier (walk-codes rest foreground (cons modifier modifiers))]
        [else (walk-codes rest foreground modifiers)]))))

(define (parse-appearance value)
  (walk-codes (split-many value ";") #f '()))

; A pattern is always `*` followed by a literal suffix. Every rule `vivid` and
; `dircolors` emit has that shape, so matching is a suffix test.
(define (rule-suffix key)
  (and
    (> (string-length key) 1)
    (char=? (string-ref key 0) #\*)
    (substring key 1 (string-length key))))

; One dotted segment is the common case, so those rules get a direct index
; instead of joining the scanned ones.
(define (rule-extension suffix)
  (and
    (> (string-length suffix) 1)
    (char=? (string-ref suffix 0) #\.)
    (let ([rest (substring suffix 1 (string-length suffix))])
      (and (not (string-contains? rest ".")) rest))))

(define (final-character text)
  (string-ref text (- (string-length text) 1)))

; Scanned rules keep reverse spec order, so a later rule wins an equal-length
; tie the way GNU `ls` resolves one.
(define (add-scanned scanned suffix appearance)
  (define bucket (final-character suffix))
  (hash-insert
    scanned
    bucket
    (cons
      (cons suffix appearance)
      (or (hash-try-get scanned bucket) '()))))

(define (parse text)
  (let loop ([remaining (split-many text ":")]
             [types (hash)]
             [extensions (hash)]
             [scanned (hash)])
    (if
      (null? remaining)
      (palette-value types extensions scanned)
      (let* ([fields (split-once (trim (car remaining)) "=")]
             [key (and (list? fields) (car fields))]
             [value (and key (car (cdr fields)))]
             [suffix (and key (> (string-length key) 0) (rule-suffix key))]
             [extension (and suffix (rule-extension suffix))])
        (cond
          [(not (and key (> (string-length key) 0)))
            (loop (cdr remaining) types extensions scanned)]
          [extension
            (loop
              (cdr remaining)
              types
              (hash-insert extensions extension (parse-appearance value))
              scanned)]
          [suffix
            (loop
              (cdr remaining)
              types
              extensions
              (add-scanned scanned suffix (parse-appearance value)))]
          [else
            (loop
              (cdr remaining)
              (hash-insert types key (parse-appearance value))
              extensions
              scanned)])))))

(define (extension-of label)
  (let loop ([index (- (string-length label) 1)])
    (cond
      [(< index 0) #f]
      [(char=? (string-ref label index) #\.)
        (substring label (+ index 1) (string-length label))]
      [else (loop (- index 1))])))

(define (indexed-appearance palette label)
  (define extension (extension-of label))
  (and
    extension
    (hash-try-get (palette-value-extensions palette) extension)))

(define (indexed-length label)
  (define extension (extension-of label))
  (if extension (+ (string-length extension) 1) 0))

; A suffix can only match when its last character does, so one bucket holds
; every rule worth testing. The longest match wins, which is what makes
; `*README.md` beat `*.md` without any rule ordering.
(define (scanned-appearance palette label best-length best)
  (let loop ([remaining
               (or
                 (hash-try-get
                   (palette-value-scanned palette)
                   (final-character label))
                 '())]
             [length best-length]
             [found best])
    (if
      (null? remaining)
      found
      (let* ([rule (car remaining)]
             [size (string-length (car rule))])
        (if
          (and (> size length) (ends-with? label (car rule)))
          (loop (cdr remaining) size (cdr rule))
          (loop (cdr remaining) length found))))))

(define (pattern-appearance palette label)
  (define indexed (indexed-appearance palette label))
  (scanned-appearance
    palette
    label
    (if indexed (indexed-length label) 0)
    indexed))

; Only regular files consult patterns. Every other kind takes its type rule,
; exactly as GNU `ls` and `eza` resolve them.
(define (appearance-for palette label kind)
  (define matched
    (and
      (equal? kind 'file)
      (> (string-length label) 0)
      (pattern-appearance palette label)))
  (or matched (hash-try-get (palette-value-types palette) (type-key kind))))
