#lang racket
(require web-server/servlet
         web-server/servlet-env
         racket/list
         racket/file
         json)

; File path for storing messages
(define message-file "/var/www/curl-tut/message.json")

; Helper function to read the current message from file
(define (read-message)
  (if (file-exists? message-file)
      (call-with-input-file message-file
        (lambda (in) (read-json in)))
      (hasheq)))

; Helper function to write a message to file
(define (write-message msg-hash)
  (call-with-output-file message-file
    (lambda (out) (write-json msg-hash out))
    #:exists 'replace))

; In-memory color state
(define color-state
  (make-hash `((r . 128.0)
               (g . 128.0)
               (b . 128.0)
               (rate . 1.0)
               (target-r . #f)
               (target-g . #f)
               (target-b . #f)
               (last-update . ,(current-inexact-milliseconds))
               (noise-offset . 0.0))))

; Get phase offset for each color channel (creates different patterns)
(define (channel-phase ch)
  (case ch
    [(r) 0.0]
    [(g) 2.1]
    [(b) 4.2]
    [else 0.0]))

; Update colors based on elapsed time
(define (update-colors!)
  (define now (current-inexact-milliseconds))
  (define last (hash-ref color-state 'last-update))
  (define dt (/ (- now last) 1000.0))  ; delta time in seconds
  (define rate (hash-ref color-state 'rate))

  ; Update noise offset
  (define offset (+ (hash-ref color-state 'noise-offset) (* dt rate 0.5)))
  (hash-set! color-state 'noise-offset offset)

  ; Update each channel
  (for ([channel '(r g b)])
    (define current (hash-ref color-state channel))
    (define target-key (string->symbol (format "target-~a" channel)))
    (define target (hash-ref color-state target-key))
    (define new-val
      (if target
          ; Ramp towards target
          (let ([diff (- target current)])
            (if (< (abs diff) 0.5)
                (begin
                  ; Reached target, clear it and resume normal evolution
                  (hash-set! color-state target-key #f)
                  target)
                ; Move towards target
                (+ current (* diff (min 1.0 (* dt rate 2.0))))))
          ; Evolve with sine wave
          (+ 128 (* 127 (sin (+ offset (* (channel-phase channel) 1.0)))))))
    (hash-set! color-state channel (max 0.0 (min 255.0 new-val))))

  (hash-set! color-state 'last-update now))

; Dispatch-values
(define-values (servlet-dispatch servlet-url)
  (dispatch-rules
  [("message") #:method "get" get-message-endpoint]
  [("message") #:method "post" post-message-endpoint]
  [("color") #:method "get" get-color-endpoint]
  [("color") #:method "post" post-color-endpoint]
  [("health") #:method "get" health-endpoint]
  [("") #:method "get" welcome-endpoint]
  [else welcome-endpoint]))

(define (welcome-endpoint req)
  (response/xexpr
    "\n\nWelcome! This is my little API.\n
It is written in Racket, and will continue to grow until the end of class.\n\n
=== MESSAGE BOARD ===\n
  GET /message\n
    Retrieve the current message from the \"wall\"\n\n
  POST /message\n
    Post a message to the wall\n
    Body: {\"name\": \"Your name\", \"message\": \"Something you feel like saying\"}\n\n
=== DYNAMIC COLOR ===\n
  GET /color\n
    Returns current RGB color values that evolve smoothly over time\n
    Response: {\"r\": 0-255, \"g\": 0-255, \"b\": 0-255, \"rate\": number}\n\n
  POST /color\n
    Influence the color evolution\n
    Body (all optional):\n
      {\"rate\": 0-10}        - Speed of color changes (0=frozen, 10=fastest)\n
      {\"r\": 0-255}          - Target red value\n
      {\"g\": 0-255}          - Target green value\n
      {\"b\": 0-255}          - Target blue value\n
    Example: {\"rate\": 2.5, \"r\": 255, \"g\": 0, \"b\": 128}\n\n
=== SYSTEM ===\n
  GET /health\n
    Health check endpoint\n\n"))

(define (health-endpoint req)
  (response/jsexpr
    (hasheq 'status "healthy"
            'timestamp (exact->inexact (current-seconds)))))

(define (get-message-endpoint req)
  (define msg (read-message))
  (if (hash-empty? msg)
      (response/jsexpr
        (hasheq 'status "ERROR"
                'error "No message available")
        #:code 404)
      (response/jsexpr msg)))

(define (post-message-endpoint req)
  (define bindings (request-bindings req))
  (define json-data (bytes->jsexpr (request-post-data/raw req)))
  (define name (hash-ref json-data 'name #f))
  (define message (hash-ref json-data 'message #f))

  (if (and name message)
      (begin
        (write-message (hasheq 'set-at (current-seconds)
                               'by-person name
                               'message message))
        (response/jsexpr
          (hasheq 'status "OK")))
      (response/jsexpr
        (hasheq 'status "ERROR"
                'error "Missing 'name' or 'message' field")
        #:code 400)))

(define (get-color-endpoint req)
  ; Update colors before returning
  (update-colors!)
  ; Return current RGB values (rounded to integers)
  (response/jsexpr
    (hasheq 'r (exact->inexact (round (hash-ref color-state 'r)))
            'g (exact->inexact (round (hash-ref color-state 'g)))
            'b (exact->inexact (round (hash-ref color-state 'b)))
            'rate (hash-ref color-state 'rate))))

(define (post-color-endpoint req)
  ; Add error handling for malformed JSON
  (with-handlers ([exn:fail? (lambda (e)
                               (response/jsexpr
                                 (hasheq 'status "ERROR"
                                         'error "Invalid JSON")
                                 #:code 400))])
    (define json-data (bytes->jsexpr (request-post-data/raw req)))

    ; Update rate if provided (cap at 10.0 to prevent jarring changes)
    (when (hash-has-key? json-data 'rate)
      (define rate (hash-ref json-data 'rate))
      (if (and (number? rate) (>= rate 0) (<= rate 10.0))
          (hash-set! color-state 'rate rate)
          (void)))

    ; Update target values if provided
    (for ([channel '(r g b)])
      (when (hash-has-key? json-data channel)
        (define val (hash-ref json-data channel))
        (define target-key (string->symbol (format "target-~a" channel)))
        (if (and (number? val) (>= val 0) (<= val 255))
            (hash-set! color-state target-key (exact->inexact val))
            (void))))

    (response/jsexpr
      (hasheq 'status "OK"
              'message "Color parameters updated"))))

(define (start req)
  (displayln (request-uri req))
  (servlet-dispatch req))

  (serve/servlet start
#:port 4321
#:servlet-path "/"
#:servlet-regexp #rx""
#:command-line? #t)


