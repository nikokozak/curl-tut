#lang racket
(require web-server/servlet
         web-server/servlet-env
         racket/list
         racket/file)

; Dispatch-values
(define-values (servlet-dispatch servlet-url)
  (dispatch-rules
  [("posts") review-posts]
  [("archive") review-archive]
  [("") list-posts]
  [else list-posts]))

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


