#lang racket
(require web-server/servlet
         web-server/servlet-env
         racket/list
         racket/file
         json)

; File path for storing messages
(define message-file "message.json")

; Helper function to read the current message from file
(define (read-message)
  (if (file-exists? message-file)
      (call-with-input-file message-file
        (lambda (in) (read-json in)))
      #hasheq()))

; Helper function to write a message to file
(define (write-message msg-hash)
  (call-with-output-file message-file
    (lambda (out) (write-json msg-hash out))
    #:exists 'replace))

; Dispatch-values
(define-values (servlet-dispatch servlet-url)
  (dispatch-rules
  [("message") #:method "get" get-message-endpoint]
  [("message") #:method "post" post-message-endpoint]
  [("health") #:method "get" health-endpoint]
  [("") #:method "get" welcome-endpoint]
  [else welcome-endpoint]))

(define (welcome-endpoint req)
  (response/xexpr
    "\n\nWelcome! This is my little API.\n
It is written in Racket, and will continue to grow until the end of class.\n
For now, you can do the following:\n\n
  GET /message - Retrieve the current message from the \"wall\"\n
  POST /message - Post a message to the wall in the format {\"name\": \"Your name\", \"message\": \"Something you feel like saying\"}\n
  GET /health - Health check endpoint\n\n"))

(define (health-endpoint req)
  (response/jsexpr
    (hasheq 'status "healthy"
            'timestamp (exact->inexact (current-seconds)))))

(define (get-message-endpoint req)
  (define msg (read-message))
  (if (hash-empty? msg)
      (response/jsexpr
        #hasheq((status . "ERROR")
                (error . "No message available"))
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
          #hasheq((status . "OK"))))
      (response/jsexpr
        #hasheq((status . "ERROR")
                (error . "Missing 'name' or 'message' field"))
        #:code 400)))

(define (start req)
  (displayln (request-uri req))
  (servlet-dispatch req))

  (serve/servlet start
#:port 4321
#:servlet-path "/"
#:servlet-regexp #rx""
#:command-line? #t)


