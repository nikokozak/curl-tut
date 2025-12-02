#lang racket

(require web-server/servlet
         web-server/http/response-structs
         web-server/http/request-structs
         json
         file/sha1
         racket/random
         racket/pretty)

(provide academy-welcome
         academy-level-handler
         response/jsexpr-pretty)

;; ============================================================================
;; CONFIGURATION
;; ============================================================================

;; Use relative path for local dev, absolute for production
(define cookie-file
  (let ([prod-path "/var/www/curl-tut/academy-cookies.json"])
    (if (directory-exists? "/var/www/curl-tut")
        prod-path
        "academy-cookies.json")))
(define total-levels 20)

;; ============================================================================
;; HELPER FUNCTIONS
;; ============================================================================

;; Generate a deterministic ID from a name
(define (generate-id name)
  (define hash-hex (sha1 (open-input-string name)))
  (string-append name "_" (substring hash-hex 0 5)))

;; Extract a header value from request (case-insensitive)
(define (get-header req header-name)
  (define h (headers-assq* (string->bytes/utf-8 (string-downcase header-name))
                           (request-headers/raw req)))
  (and h (bytes->string/utf-8 (header-value h))))

;; Get the HTTP method as a lowercase string
(define (get-method req)
  (string-downcase (bytes->string/utf-8 (request-method req))))

;; Check if method matches expected
(define (method-is? req expected)
  (string=? (get-method req) (string-downcase expected)))

;; Get query parameter from URL
(define (get-query-param req param-name)
  (define bindings (request-bindings/raw req))
  (define binding (bindings-assq (string->bytes/utf-8 param-name) bindings))
  (and binding
       (binding:form? binding)
       (bytes->string/utf-8 (binding:form-value binding))))

;; Get form/body parameter (for POST/PUT/PATCH with form data)
(define (get-body-param req param-name)
  (get-query-param req param-name)) ; Same mechanism for form-encoded

;; Parse JSON body, returns #f on failure
(define (get-json-body req)
  (with-handlers ([exn:fail? (lambda (e) #f)])
    (define raw (request-post-data/raw req))
    (and raw (bytes->jsexpr raw))))

;; Read cookies from file
(define (read-cookies)
  (if (file-exists? cookie-file)
      (with-handlers ([exn:fail? (lambda (e) (hasheq))])
        (call-with-input-file cookie-file read-json))
      (hasheq)))

;; Write cookies to file
(define (write-cookies cookies)
  (call-with-output-file cookie-file
    (lambda (out) (write-json cookies out))
    #:exists 'replace))

;; Generate a random token
(define (generate-token)
  (define chars "abcdefghijklmnopqrstuvwxyz0123456789")
  (list->string
   (for/list ([_ (in-range 16)])
     (string-ref chars (random (string-length chars))))))

;; Pretty-print JSON with indentation
(define (json-pretty obj [indent 0])
  (define pad (make-string indent #\space))
  (define pad2 (make-string (+ indent 2) #\space))
  (cond
    [(hash? obj)
     (if (hash-empty? obj)
         "{}"
         (string-append
          "{\n"
          (string-join
           (for/list ([(k v) (in-hash obj)])
             (format "~a~s: ~a" pad2 (symbol->string k) (json-pretty v (+ indent 2))))
           ",\n")
          "\n" pad "}"))]
    [(list? obj)
     (if (null? obj)
         "[]"
         (string-append
          "[\n"
          (string-join
           (for/list ([item obj])
             (format "~a~a" pad2 (json-pretty item (+ indent 2))))
           ",\n")
          "\n" pad "]"))]
    [(string? obj) (format "~s" obj)]
    [(number? obj) (number->string obj)]
    [(boolean? obj) (if obj "true" "false")]
    [(eq? obj 'null) "null"]
    [else (format "~s" obj)]))

;; Pretty JSON response helper
(define (response/jsexpr-pretty obj #:code [code 200])
  (response/full
   code
   (if (= code 200) #"OK" #"Error")
   (current-seconds)
   #"application/json; charset=utf-8"
   '()
   (list (string->bytes/utf-8 (string-append (json-pretty obj) "\n")))))

;; Success response helper
(define (success-response level lesson data next-instruction next-hint next-endpoint)
  (response/jsexpr-pretty
   (hasheq 'success #t
           'level level
           'lesson lesson
           'data data
           'next (hasheq 'instruction next-instruction
                         'hint next-hint
                         'endpoint next-endpoint))))

;; Error response helper
(define (error-response level error-msg expected hint)
  (response/jsexpr-pretty
   (hasheq 'success #f
           'level level
           'error error-msg
           'expected expected
           'hint hint
           'try_again (format "/academy/level/~a" level))
   #:code 400))

;; Method error helper
(define (method-error level expected-method got-method)
  (error-response level
                  (format "Wrong HTTP method")
                  (format "Expected ~a, got ~a" (string-upcase expected-method) (string-upcase got-method))
                  (format "curl -X ~a ..." (string-upcase expected-method))))

;; ============================================================================
;; WELCOME ENDPOINT (Level 0)
;; ============================================================================

(define (academy-welcome req)
  (response/jsexpr-pretty
   (hasheq 'message "Welcome to Curl Academy!"
           'description "Learn curl through 20 progressive challenges"
           'your_journey "Master HTTP methods, headers, authentication, and more"
           'start "/academy/level/1"
           'hint "curl https://api.nkozak.com/academy/level/1"
           'total_levels total-levels)))

;; ============================================================================
;; LEVEL HANDLER
;; ============================================================================

(define (academy-level-handler req level-num)
  (cond
    [(or (< level-num 1) (> level-num total-levels))
     (response/jsexpr-pretty
      (hasheq 'error "Level not found"
              'message (format "Levels go from 1 to ~a" total-levels)
              'hint "Start with /academy/level/1")
      #:code 404)]
    [else
     (handle-level req level-num)]))

;; ============================================================================
;; LEVEL IMPLEMENTATIONS
;; ============================================================================

(define (handle-level req level-num)
  (case level-num
    ;; ========================================================================
    ;; TIER 1: HTTP METHODS (Levels 1-6)
    ;; ========================================================================

    [(1) (level-1-basic-get req)]
    [(2) (level-2-query-params req)]
    [(3) (level-3-post-basics req)]
    [(4) (level-4-put req)]
    [(5) (level-5-patch req)]
    [(6) (level-6-delete req)]

    ;; ========================================================================
    ;; TIER 2: HEADERS (Levels 7-10)
    ;; ========================================================================

    [(7) (level-7-user-agent req)]
    [(8) (level-8-content-type-json req)]
    [(9) (level-9-accept-header req)]
    [(10) (level-10-custom-header req)]

    ;; ========================================================================
    ;; TIER 3: AUTHENTICATION (Levels 11-13)
    ;; ========================================================================

    [(11) (level-11-basic-auth req)]
    [(12) (level-12-bearer-token req)]
    [(13) (level-13-multiple-headers req)]

    ;; ========================================================================
    ;; TIER 4: ADVANCED REQUESTS (Levels 14-17)
    ;; ========================================================================

    [(14) (level-14-nested-json req)]
    [(15) (level-15-head-request req)]
    [(16) (level-16-follow-redirects req)]
    [(17) (level-17-query-and-body req)]

    ;; ========================================================================
    ;; TIER 5: COOKIES & GRADUATION (Levels 18-20)
    ;; ========================================================================

    [(18) (level-18-receive-cookie req)]
    [(19) (level-19-send-cookie req)]
    [(20) (level-20-graduation req)]

    [else (response/jsexpr-pretty (hasheq 'error "Level not implemented") #:code 500)]))

;; ============================================================================
;; TIER 1: HTTP METHODS
;; ============================================================================

;; Level 1: Basic GET - Just teaches curl basics, always succeeds
(define (level-1-basic-get req)
  (success-response
   1
   "GET is the default HTTP method - it retrieves data from servers"
   (hasheq 'method_used (string-upcase (get-method req))
           'tip "curl uses GET by default when you don't specify a method")
   "Now let's add query parameters to your request"
   "curl 'https://api.nkozak.com/academy/level/2?name=YOUR_NAME&ready=true'"
   "/academy/level/2?name=YOUR_NAME&ready=true"))

;; Level 2: Query Parameters
(define (level-2-query-params req)
  (define name (get-query-param req "name"))
  (define ready (get-query-param req "ready"))
  (cond
    [(not name)
     (error-response 2 "Missing 'name' parameter"
                     "Add ?name=YOUR_NAME to the URL"
                     "curl 'https://api.nkozak.com/academy/level/2?name=alice&ready=true'")]
    [(not (equal? ready "true"))
     (error-response 2 "Missing or wrong 'ready' parameter"
                     "Add &ready=true to the URL"
                     "curl 'https://api.nkozak.com/academy/level/2?name=alice&ready=true'")]
    [else
     (define user-id (generate-id name))
     (success-response
      2
      "Query parameters pass data in the URL after the ? symbol, separated by &"
      (hasheq 'parsed (hasheq 'name name 'ready ready)
              'your_id user-id
              'remember "Save your ID - you'll need it for the next levels!")
      "Time to send data with POST! Include your ID in the request body"
      (format "curl -X POST -d 'id=~a' https://api.nkozak.com/academy/level/3" user-id)
      "/academy/level/3")]))

;; Level 3: POST Basics
(define (level-3-post-basics req)
  (cond
    [(not (method-is? req "post"))
     (method-error 3 "POST" (get-method req))]
    [else
     (define id (get-body-param req "id"))
     (cond
       [(not id)
        (error-response 3 "Missing 'id' in request body"
                        "POST body should contain id=YOUR_ID"
                        "curl -X POST -d 'id=yourname_xxxxx' https://api.nkozak.com/academy/level/3")]
       [else
        (success-response
         3
         "POST sends data to create or submit resources. Use -d to include form data"
         (hasheq 'received_id id
                 'resource_created (format "/users/~a" id))
         "Now update your resource with PUT"
         (format "curl -X PUT -d 'status=active' https://api.nkozak.com/academy/level/4" )
         "/academy/level/4")])]))

;; Level 4: PUT
(define (level-4-put req)
  (cond
    [(not (method-is? req "put"))
     (method-error 4 "PUT" (get-method req))]
    [else
     (define status (get-body-param req "status"))
     (cond
       [(not (equal? status "active"))
        (error-response 4 "Wrong or missing 'status' value"
                        "Body should contain status=active"
                        "curl -X PUT -d 'status=active' https://api.nkozak.com/academy/level/4")]
       [else
        (success-response
         4
         "PUT replaces an entire resource. It's idempotent - same request = same result"
         (hasheq 'status_set status
                 'note "PUT typically replaces ALL fields, not just one")
         "PATCH is for partial updates - change just the level field"
         "curl -X PATCH -d 'level=5' https://api.nkozak.com/academy/level/5"
         "/academy/level/5")])]))

;; Level 5: PATCH
(define (level-5-patch req)
  (cond
    [(not (method-is? req "patch"))
     (method-error 5 "PATCH" (get-method req))]
    [else
     (define level-val (get-body-param req "level"))
     (cond
       [(not (equal? level-val "5"))
        (error-response 5 "Wrong or missing 'level' value"
                        "Body should contain level=5"
                        "curl -X PATCH -d 'level=5' https://api.nkozak.com/academy/level/5")]
       [else
        (success-response
         5
         "PATCH updates specific fields only, unlike PUT which replaces everything"
         (hasheq 'updated_field "level"
                 'new_value level-val)
         "Time to DELETE! But be careful - add a confirmation header"
         "curl -X DELETE -H 'Confirm: yes' https://api.nkozak.com/academy/level/6"
         "/academy/level/6")])]))

;; Level 6: DELETE with headers
(define (level-6-delete req)
  (cond
    [(not (method-is? req "delete"))
     (method-error 6 "DELETE" (get-method req))]
    [else
     (define confirm (get-header req "confirm"))
     (cond
       [(not (equal? confirm "yes"))
        (error-response 6 "Missing confirmation header"
                        "Include header 'Confirm: yes'"
                        "curl -X DELETE -H 'Confirm: yes' https://api.nkozak.com/academy/level/6")]
       [else
        (success-response
         6
         "DELETE removes resources. Headers carry metadata - use -H to add them"
         (hasheq 'deleted #t
                 'confirmation_received confirm)
         "Now pretend to be a bot by changing your User-Agent"
         "curl -H 'User-Agent: CurlBot/1.0' https://api.nkozak.com/academy/level/7"
         "/academy/level/7")])]))

;; ============================================================================
;; TIER 2: HEADERS
;; ============================================================================

;; Level 7: User-Agent
(define (level-7-user-agent req)
  (define ua (get-header req "user-agent"))
  (cond
    [(not (and ua (string-contains? ua "CurlBot/1.0")))
     (error-response 7 "Wrong User-Agent"
                     "Set User-Agent to 'CurlBot/1.0'"
                     "curl -H 'User-Agent: CurlBot/1.0' https://api.nkozak.com/academy/level/7\n  or: curl -A 'CurlBot/1.0' https://api.nkozak.com/academy/level/7")]
    [else
     (success-response
      7
      "User-Agent identifies your client. -A is shorthand for -H 'User-Agent: ...'"
      (hasheq 'detected_agent ua
              'message "BEEP BOOP - BOT RECOGNIZED")
      "Send JSON data with the proper Content-Type header"
      "curl -H 'Content-Type: application/json' -d '{\"bot\":true,\"version\":\"1.0\"}' https://api.nkozak.com/academy/level/8"
      "/academy/level/8")]))

;; Level 8: Content-Type JSON
(define (level-8-content-type-json req)
  (define ct (get-header req "content-type"))
  (define json-body (get-json-body req))
  (cond
    [(not (and ct (string-contains? ct "application/json")))
     (error-response 8 "Wrong or missing Content-Type"
                     "Set Content-Type to 'application/json'"
                     "curl -H 'Content-Type: application/json' -d '{\"bot\":true}' ...")]
    [(not json-body)
     (error-response 8 "Invalid or missing JSON body"
                     "Body must be valid JSON"
                     "curl -H 'Content-Type: application/json' -d '{\"bot\":true,\"version\":\"1.0\"}' ...")]
    [(not (and (hash-ref json-body 'bot #f) (hash-ref json-body 'version #f)))
     (error-response 8 "JSON missing required fields"
                     "JSON must have 'bot' and 'version' fields"
                     "curl -H 'Content-Type: application/json' -d '{\"bot\":true,\"version\":\"1.0\"}' ...")]
    [else
     (success-response
      8
      "Content-Type tells the server what format your data is in. JSON is very common!"
      (hasheq 'received json-body
              'tip "Always set Content-Type when sending data")
      "Request JSON back using the Accept header"
      "curl -H 'Accept: application/json' https://api.nkozak.com/academy/level/9"
      "/academy/level/9")]))

;; Level 9: Accept Header
(define (level-9-accept-header req)
  (define accept (get-header req "accept"))
  (cond
    [(not (and accept (string-contains? accept "application/json")))
     (error-response 9 "Wrong or missing Accept header"
                     "Set Accept to 'application/json'"
                     "curl -H 'Accept: application/json' https://api.nkozak.com/academy/level/9")]
    [else
     (define user-id (or (get-query-param req "id") "student_00000"))
     (success-response
      9
      "Accept tells the server what format you want the response in"
      (hasheq 'you_requested accept
              'we_sent "application/json"
              'your_token user-id)
      "Send a custom header with your token"
      (format "curl -H 'X-Academy-Token: ~a' https://api.nkozak.com/academy/level/10" user-id)
      "/academy/level/10")]))

;; Level 10: Custom Header
(define (level-10-custom-header req)
  (define token (get-header req "x-academy-token"))
  (cond
    [(not token)
     (error-response 10 "Missing X-Academy-Token header"
                     "Add header 'X-Academy-Token: YOUR_ID'"
                     "curl -H 'X-Academy-Token: yourname_xxxxx' https://api.nkozak.com/academy/level/10")]
    [(< (string-length token) 3)
     (error-response 10 "Invalid token"
                     "Token should be your ID from earlier"
                     "curl -H 'X-Academy-Token: yourname_xxxxx' https://api.nkozak.com/academy/level/10")]
    [else
     (success-response
      10
      "Custom headers (X-*) are used for app-specific data like tokens"
      (hasheq 'token_received token
              'headers_mastered #t)
      "Time for authentication! Use HTTP Basic Auth"
      (format "curl -u '~a:secret123' https://api.nkozak.com/academy/level/11" token)
      "/academy/level/11")]))

;; ============================================================================
;; TIER 3: AUTHENTICATION
;; ============================================================================

;; Level 11: Basic Auth
(define (level-11-basic-auth req)
  (define auth (get-header req "authorization"))
  (cond
    [(not auth)
     (error-response 11 "Missing Authorization header"
                     "Use Basic Authentication"
                     "curl -u 'username:password' https://api.nkozak.com/academy/level/11")]
    [(not (string-prefix? auth "Basic "))
     (error-response 11 "Wrong authentication type"
                     "Use Basic Authentication (not Bearer, etc)"
                     "curl -u 'yourname_xxxxx:secret123' https://api.nkozak.com/academy/level/11")]
    [else
     ;; Decode and check - in real app you'd validate credentials
     (success-response
      11
      "Basic Auth sends base64-encoded username:password. -u is the easy way!"
      (hasheq 'auth_type "Basic"
              'note "In production, ALWAYS use HTTPS with Basic Auth!"
              'curl_tip "-u automatically adds the Authorization header")
      "Now try Bearer token authentication"
      "curl -H 'Authorization: Bearer your_token_here' https://api.nkozak.com/academy/level/12"
      "/academy/level/12")]))

;; Level 12: Bearer Token
(define (level-12-bearer-token req)
  (define auth (get-header req "authorization"))
  (cond
    [(not auth)
     (error-response 12 "Missing Authorization header"
                     "Add Bearer token"
                     "curl -H 'Authorization: Bearer your_token' https://api.nkozak.com/academy/level/12")]
    [(not (string-prefix? auth "Bearer "))
     (error-response 12 "Wrong authentication type"
                     "Use Bearer token (not Basic)"
                     "curl -H 'Authorization: Bearer your_token' https://api.nkozak.com/academy/level/12")]
    [else
     (define token (substring auth 7))
     (success-response
      12
      "Bearer tokens are common for API auth. Unlike Basic, you construct the header manually"
      (hasheq 'auth_type "Bearer"
              'token_received token
              'common_uses '("OAuth2" "JWT" "API keys"))
      "Combine multiple headers in one request!"
      "curl -H 'Content-Type: application/json' -H 'Authorization: Bearer token' -H 'X-Request-ID: 12345' -d '{\"action\":\"test\"}' https://api.nkozak.com/academy/level/13"
      "/academy/level/13")]))

;; Level 13: Multiple Headers
(define (level-13-multiple-headers req)
  (define ct (get-header req "content-type"))
  (define auth (get-header req "authorization"))
  (define req-id (get-header req "x-request-id"))
  (define json-body (get-json-body req))
  (cond
    [(not (and ct (string-contains? ct "application/json")))
     (error-response 13 "Missing Content-Type header"
                     "Need Content-Type: application/json"
                     "curl -H 'Content-Type: application/json' -H 'Authorization: Bearer x' -H 'X-Request-ID: 123' -d '{\"action\":\"test\"}' ...")]
    [(not auth)
     (error-response 13 "Missing Authorization header"
                     "Need Authorization: Bearer YOUR_TOKEN"
                     "curl -H 'Content-Type: application/json' -H 'Authorization: Bearer x' -H 'X-Request-ID: 123' -d '{\"action\":\"test\"}' ...")]
    [(not req-id)
     (error-response 13 "Missing X-Request-ID header"
                     "Need X-Request-ID: SOME_VALUE"
                     "curl -H 'Content-Type: application/json' -H 'Authorization: Bearer x' -H 'X-Request-ID: 123' -d '{\"action\":\"test\"}' ...")]
    [(not json-body)
     (error-response 13 "Invalid or missing JSON body"
                     "Need valid JSON with 'action' field"
                     "curl ... -d '{\"action\":\"test\"}' ...")]
    [else
     (success-response
      13
      "Real APIs often require multiple headers. Add as many -H flags as needed!"
      (hasheq 'headers_received (hasheq 'content-type ct
                                        'authorization (if (> (string-length auth) 20)
                                                           (string-append (substring auth 0 20) "...")
                                                           auth)
                                        'x-request-id req-id)
              'body_received json-body)
      "Time for complex JSON structures!"
      "curl -H 'Content-Type: application/json' -d '{\"user\":{\"name\":\"test\",\"level\":14},\"verified\":true}' https://api.nkozak.com/academy/level/14"
      "/academy/level/14")]))

;; ============================================================================
;; TIER 4: ADVANCED REQUESTS
;; ============================================================================

;; Level 14: Nested JSON
(define (level-14-nested-json req)
  (define json-body (get-json-body req))
  (cond
    [(not json-body)
     (error-response 14 "Invalid or missing JSON body"
                     "Send valid nested JSON"
                     "curl -H 'Content-Type: application/json' -d '{\"user\":{\"name\":\"test\",\"level\":14},\"verified\":true}' ...")]
    [else
     (define user (hash-ref json-body 'user #f))
     (define verified (hash-ref json-body 'verified #f))
     (cond
       [(not (hash? user))
        (error-response 14 "Missing 'user' object"
                        "JSON needs a 'user' object with nested fields"
                        "curl -H 'Content-Type: application/json' -d '{\"user\":{\"name\":\"test\",\"level\":14},\"verified\":true}' ...")]
       [(not (and (hash-ref user 'name #f) (hash-ref user 'level #f)))
        (error-response 14 "User object missing fields"
                        "user needs 'name' and 'level' fields"
                        "curl -H 'Content-Type: application/json' -d '{\"user\":{\"name\":\"test\",\"level\":14},\"verified\":true}' ...")]
       [(not verified)
        (error-response 14 "Missing 'verified' field"
                        "Add verified:true to the JSON"
                        "curl -H 'Content-Type: application/json' -d '{\"user\":{\"name\":\"test\",\"level\":14},\"verified\":true}' ...")]
       [else
        (success-response
         14
         "JSON can have nested objects and arrays. Escape quotes carefully in shell!"
         (hasheq 'parsed json-body
                 'tip "Use single quotes around JSON to avoid escaping issues")
         "Try a HEAD request - get headers without the body"
         "curl -I https://api.nkozak.com/academy/level/15"
         "/academy/level/15")])]))

;; Level 15: HEAD Request
(define (level-15-head-request req)
  (cond
    [(not (method-is? req "head"))
     (method-error 15 "HEAD" (get-method req))]
    [else
     ;; HEAD responses shouldn't have a body, but we need to communicate success
     ;; The lesson is in the headers! We'll add a custom header.
     (response/full
      200
      #"OK"
      (current-seconds)
      #"application/json"
      (list (header #"X-Lesson" #"HEAD returns headers only - useful for checking if resources exist")
            (header #"X-Next-Level" #"/academy/level/16")
            (header #"X-Hint" #"curl -L follows redirects. Try: curl -L https://api.nkozak.com/academy/level/16")
            (header #"X-Success" #"true"))
      '())]))

;; Level 16: Follow Redirects
(define (level-16-follow-redirects req)
  ;; Check if this is the redirected request (has special header)
  (define followed (get-header req "x-followed-redirect"))
  (define from-redirect (get-query-param req "redirected"))
  (cond
    [from-redirect
     ;; They followed the redirect!
     (success-response
      16
      "The -L flag tells curl to follow redirects. Essential for real-world use!"
      (hasheq 'redirects_followed #t
              'tip "Many URLs redirect (http->https, www->non-www, etc)")
      "Combine query parameters with a POST body"
      "curl -X POST -d 'action=submit' 'https://api.nkozak.com/academy/level/17?format=json&confirm=true'"
      "/academy/level/17")]
    [else
     ;; Send a redirect
     (response/full
      302
      #"Found"
      (current-seconds)
      #"text/plain"
      (list (header #"Location" #"/academy/level/16?redirected=true"))
      (list #"Redirecting... Use curl -L to follow!"))]))

;; Level 17: Query + Body Combo
(define (level-17-query-and-body req)
  (cond
    [(not (method-is? req "post"))
     (method-error 17 "POST" (get-method req))]
    [else
     (define format-param (get-query-param req "format"))
     (define confirm-param (get-query-param req "confirm"))
     (define action (get-body-param req "action"))
     (cond
       [(not (equal? format-param "json"))
        (error-response 17 "Missing format query parameter"
                        "Add ?format=json to the URL"
                        "curl -X POST -d 'action=submit' 'https://api.nkozak.com/academy/level/17?format=json&confirm=true'")]
       [(not (equal? confirm-param "true"))
        (error-response 17 "Missing confirm query parameter"
                        "Add &confirm=true to the URL"
                        "curl -X POST -d 'action=submit' 'https://api.nkozak.com/academy/level/17?format=json&confirm=true'")]
       [(not (equal? action "submit"))
        (error-response 17 "Missing or wrong action in body"
                        "Body should contain action=submit"
                        "curl -X POST -d 'action=submit' 'https://api.nkozak.com/academy/level/17?format=json&confirm=true'")]
       [else
        (success-response
         17
         "You can combine query params (in URL) with body data. Both are sent!"
         (hasheq 'query_params (hasheq 'format format-param 'confirm confirm-param)
                 'body_params (hasheq 'action action))
         "Time for cookies! This request will SET a cookie for you"
         "curl -c cookies.txt https://api.nkozak.com/academy/level/18\n  (-c saves cookies to a file)"
         "/academy/level/18")])]))

;; ============================================================================
;; TIER 5: COOKIES & GRADUATION
;; ============================================================================

;; Level 18: Receive Cookie
(define (level-18-receive-cookie req)
  ;; Generate a unique session token
  (define token (generate-token))
  (define session-id (format "session_~a" token))

  ;; Store in file for validation in level 19
  (define cookies (read-cookies))
  (define updated (hash-set cookies
                            (string->symbol session-id)
                            (hasheq 'token token
                                    'issued_at (current-seconds))))
  (write-cookies updated)

  ;; Return response with Set-Cookie header
  (response/full
   200
   #"OK"
   (current-seconds)
   #"application/json"
   (list (header #"Set-Cookie"
                 (string->bytes/utf-8 (format "academy_session=~a; Path=/academy" session-id))))
   (list (string->bytes/utf-8
          (jsexpr->string
           (hasheq 'success #t
                   'level 18
                   'lesson "Servers send cookies with Set-Cookie header. Use -c to save them!"
                   'data (hasheq 'cookie_name "academy_session"
                                 'your_session session-id
                                 'tip "Run: curl -c cookies.txt to save cookies to a file")
                   'next (hasheq 'instruction "Send the cookie back with your next request"
                                 'hint "curl -b cookies.txt https://api.nkozak.com/academy/level/19\n  or: curl -b 'academy_session=YOUR_SESSION' ..."
                                 'endpoint "/academy/level/19")))))))

;; Level 19: Send Cookie
(define (level-19-send-cookie req)
  (define cookie-header (get-header req "cookie"))
  (cond
    [(not cookie-header)
     (error-response 19 "No cookie sent"
                     "Include the cookie from level 18"
                     "curl -b cookies.txt https://api.nkozak.com/academy/level/19\n  or: curl -b 'academy_session=session_xxx' ...")]
    [(not (string-contains? cookie-header "academy_session="))
     (error-response 19 "Wrong cookie"
                     "Send the academy_session cookie"
                     "curl -b 'academy_session=YOUR_SESSION' https://api.nkozak.com/academy/level/19")]
    [else
     ;; Extract and validate session
     (define session-match (regexp-match #rx"academy_session=([a-z0-9_]+)" cookie-header))
     (cond
       [(not session-match)
        (error-response 19 "Invalid cookie format"
                        "Cookie should be academy_session=session_xxx"
                        "curl -b 'academy_session=session_xxx' https://api.nkozak.com/academy/level/19")]
       [else
        (define session-id (cadr session-match))
        (define cookies (read-cookies))
        (define stored (hash-ref cookies (string->symbol session-id) #f))
        (cond
          [(not stored)
           (error-response 19 "Session not found or expired"
                           "Get a fresh cookie from level 18"
                           "curl -c cookies.txt https://api.nkozak.com/academy/level/18")]
          [else
           (success-response
            19
            "Cookies maintain state across requests. -b sends cookies, -c saves them!"
            (hasheq 'session_valid #t
                    'session_id session-id
                    'cookie_commands (hasheq 'save "-c filename"
                                             'send "-b filename"
                                             'both "-c cookies.txt -b cookies.txt"))
            "FINAL CHALLENGE: Combine everything you've learned!"
            (format "curl -X POST -H 'Content-Type: application/json' -H 'Authorization: Bearer graduate' -b 'academy_session=~a' -d '{\"status\":\"complete\",\"levels_passed\":19}' https://api.nkozak.com/academy/level/20" session-id)
            "/academy/level/20")])])]))

;; Level 20: Graduation
(define (level-20-graduation req)
  (cond
    [(not (method-is? req "post"))
     (method-error 20 "POST" (get-method req))]
    [else
     (define ct (get-header req "content-type"))
     (define auth (get-header req "authorization"))
     (define cookie (get-header req "cookie"))
     (define json-body (get-json-body req))
     (cond
       [(not (and ct (string-contains? ct "application/json")))
        (error-response 20 "Missing Content-Type"
                        "Need Content-Type: application/json"
                        "curl -X POST -H 'Content-Type: application/json' -H 'Authorization: Bearer graduate' -b cookies.txt -d '{\"status\":\"complete\",\"levels_passed\":19}' ...")]
       [(not (equal? auth "Bearer graduate"))
        (error-response 20 "Wrong Authorization"
                        "Need Authorization: Bearer graduate"
                        "curl -X POST -H 'Content-Type: application/json' -H 'Authorization: Bearer graduate' -b cookies.txt -d '{\"status\":\"complete\",\"levels_passed\":19}' ...")]
       [(not (and cookie (string-contains? cookie "academy_session=")))
        (error-response 20 "Missing session cookie"
                        "Include your academy_session cookie"
                        "curl -X POST -H 'Content-Type: application/json' -H 'Authorization: Bearer graduate' -b cookies.txt -d '{\"status\":\"complete\",\"levels_passed\":19}' ...")]
       [(not json-body)
        (error-response 20 "Invalid JSON body"
                        "Send valid JSON with status and levels_passed"
                        "curl ... -d '{\"status\":\"complete\",\"levels_passed\":19}' ...")]
       [(not (and (equal? (hash-ref json-body 'status #f) "complete")
                  (equal? (hash-ref json-body 'levels_passed #f) 19)))
        (error-response 20 "Wrong JSON content"
                        "JSON needs status:complete and levels_passed:19"
                        "curl ... -d '{\"status\":\"complete\",\"levels_passed\":19}' ...")]
       [else
        (response/jsexpr-pretty
         (hasheq 'success #t
                 'level 20
                 'message "CONGRATULATIONS! You've mastered curl!"
                 'certificate (hasheq
                               'title "Curl Academy Graduate"
                               'skills_mastered '("HTTP methods (GET, POST, PUT, PATCH, DELETE, HEAD)"
                                                  "Query parameters"
                                                  "Request headers"
                                                  "Authentication (Basic & Bearer)"
                                                  "JSON data"
                                                  "Following redirects"
                                                  "Cookies")
                               'awarded_at (current-seconds))
                 'whats_next (hasheq
                              'explore '("-v for verbose output"
                                         "-o to save response to file"
                                         "--compressed for gzip"
                                         "-F for file uploads"
                                         "--retry for automatic retries")
                              'documentation "https://curl.se/docs/manpage.html")))])]))

;; ============================================================================
;; UTILITY: string-contains? for older Racket versions
;; ============================================================================

(define (string-contains? str substr)
  (regexp-match? (regexp-quote substr) str))

(define (string-prefix? str prefix)
  (and (>= (string-length str) (string-length prefix))
       (equal? (substring str 0 (string-length prefix)) prefix)))
