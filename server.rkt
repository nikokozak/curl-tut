#lang racket
(require web-server/servlet
         web-server/servlet-env
         racket/list
         racket/file
         json)

; Dispatch-values
(define-values (servlet-dispatch servlet-url)
  (dispatch-rules
  [("message") #:method "get" get-message-endpoint]
  [("message") #:method "post" post-message-endpoint]
  [("archive") review-archive]
  [("") welcome-endpoint]
  [else list-posts]))

(define (welcome-endpoint req)
  (response/jsexpr
    #hasheq((test . (2 3 4)))))

(define (get-message-endpoint req)
  (response/jsexpr
    #hasheq((set-at . 20342)
            (by-person . "Nikolai Kozak")
            (message . "Hey what's up?"))))

(define (post-message-endpoint req)
  (response/jsexpr
    #hasheq((status . "OK"))))

(define (list-posts req)
 (response/xexpr
  `(html (head (title "Hello"))
    (body (p "Hey posts")))))
(define (review-posts req) 
 (response/xexpr
  `(html (head (title "Hello World!"))
    (body (p "Hey review posts")))))
(define (review-archive req)
 (response/xexpr
  `(html (head (title "Hello World!"))
    (body (p "Hey review archive")))))

(define (start req)
  (displayln (request-uri req))
  (servlet-dispatch req))

  (serve/servlet start
#:port 4321
#:servlet-path "/"
#:servlet-regexp #rx""
#:command-line? #t)


