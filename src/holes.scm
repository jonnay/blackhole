;;; Utilities

;; TODO This is already defined in util.scm
(define-macro (push! list obj)
  `(set! ,list (cons ,obj ,list)))

(define (find-one? pred? lst)
    (let loop ((lst lst))
      (cond
       ((null? lst)
        #f)

       ((pair? lst)
        (if (pred? (car lst))
            #t
            (loop (cdr lst))))

       (else
        (error "Improper list" lst)))))

(define (string-for-each fn str)
  (let ((len (string-length str)))
    (let loop ((i 0))
      (cond
       ((= i len) #!void)
       (else
        (fn (string-ref str i))
        (loop (+ i 1)))))))

(define (reverse-list->string list)
  (let* ((len (length list))
         (str (make-string len)))
    (let loop ((i (- len 1))
               (list list))
      (cond
       ((pair? list)
        (string-set! str i (car list))
        (loop (- i 1) (cdr list)))))
    str))

(define (string-split chr str #!optional (sparse #f))
  (let* ((curr-str '())
         (result '())
         (new-str (lambda ()
                    (push! result (reverse-list->string curr-str))
                    (set! curr-str '())))
         (add-char (lambda (chr)
                     (push! curr-str chr))))
    (string-for-each (lambda (c)
                       (cond
                        ((eq? c chr)
                         (if (or (not sparse)
                                 (not (null? curr-str)))
                             (new-str)))
                        (else
                         (add-char c))))
                     str)
    (new-str)
    (reverse result)))

(define (read-url url)
  (with-input-from-process
   (list path: "curl"
         arguments: '("-s" "www.google.com"))
   (lambda ()
     (read))))

;;; Version numbers

(define-type version
  id: 31B8EF4A-9244-450F-8FA3-A5E914448B3A
  constructor: make-version/internal
  
  (major read-only:)
  (minor read-only:)
  (build read-only:))

(define (make-version #!optional
                      major
                      minor
                      build)
  (make-version/internal major minor build))

(define version-complete? version-build)

(define (version<? a b)
  (if (not (and (version-complete? a)
                (version-complete? b)))
      (error "Can't compare incomplete versions" a b))
  (let ((a-maj (version-major a))
        (b-maj (version-major b))
        (a-min (version-minor a))
        (b-min (version-major b))
        (a-b (version-build a))
        (b-b (version-build b))

        (v< (lambda (a b)
              (cond
               ((eq? 'max a)
                #f)
               ((eq? 'max b)
                #t)
               (else
                (< a b))))))
    (or (v< a-maj b-maj)
        (and (= a-maj b-maj)
             (or (v< a-min b-min)
                 (and (= a-min b-min)
                      (v< a-b b-b)))))))

(define (string->version str #!key force-complete?)
  (if (not (string? str))
      (error "Expected string" str))
  (let* ((str-len (string-length str))
         (str-no-v
          (if (> str-len 1)
              (substring str 1 str-len)
              (error "Invalid format" str)))
         (split-string (string-split #\. str-no-v))
         (split-string-len (length split-string)))
    (if (not (<= 0 split-string-len 3))
        (error "Invalid format" str))
    (let ((s->i
           (lambda (str)
             (let ((res (string->number str)))
               (if (or (not (integer? res))
                       (< res 0))
                   (error "Invalid format" res str))
               res))))
      (let ((res
             (make-version (and (>= split-string-len 1)
                                (s->i (car split-string)))
                           (and (>= split-string-len 2)
                                (s->i (cadr split-string)))
                           (and (= split-string-len 3)
                                (s->i (caddr split-string))))))
        (if (and force-complete?
                 (not (version-complete? res)))
            (error "Version is not complete" str))
        res))))

(define (symbol->version str #!key force-complete?)
  (string->version (symbol->string str)
                   force-complete?: force-complete?))

(define (version->string v)
  (apply
   string-append
   `("v"
     ,@(if (version-major v)
           `(,(number->string
               (version-major v))
             ,@(if (version-minor v)
                   `("."
                     ,(number->string
                       (version-minor v))
                     ,@(if (version-build v)
                           `("."
                             ,(number->string
                               (version-build v)))
                           '()))
                   '()))
           '()))))

(define (version->symbol v)
  (string->symbol (version->string v)))

(define (version-comparison pred?)
  (lambda (v ref)
    (or (not (version-major v))
        (and (pred? (version-major v)
                    (version-major ref))
             (or (not (version-minor v))
                 (and (pred? (version-minor v)
                             (version-minor ref))
                      (or (not (version-build v))
                          (pred? (version-build v)
                                 (version-build ref)))))))))
  
(define version~=? (version-comparison =))
(define version~<? (version-comparison <))
(define version~<=? (version-comparison <=))
(define version~>? (version-comparison >))
(define version~>=? (version-comparison >=))

(define version-match?
  (let ((tests
         `((< ,@version~<?)
           (<= ,@version~<=?)
           (> ,@version~>?)
           (>= ,@version~>=?)
           (= ,@version~=?))))
    (lambda (v original-exp)
      (let loop ((exp original-exp))
        (cond
         ((eq? exp #t) #t)
         
         ((eq? exp #f) #f)
         
         ((pair? exp)
          (let ((test (car exp)))
            (cond
             ((eq? 'or test)
              (find-one? loop
                         (cdr exp)))
             
             ((eq? 'and test)
              (not
               (find-one? (lambda (x)
                            (not (loop x)))
                          (cdr exp))))
             
             ((assq test tests) =>
              (lambda (test-pair)
                (if (not (and (pair? (cdr exp))
                              (null? (cddr exp))))
                    (error "Invalid expression" original-exp))
                ((cdr test-pair)
                 (symbol->version (cadr exp))
                 v)))
             
             (else
              (error "Unknown expression" original-exp)))))
          
          (else
           (error "Unknown expression" original-exp)))))))
  


;;; Package metadata

(define-type package-metadata
  id: FBD3E6A5-3587-4152-BF57-B7D5E448DAB8

  (version read-only:)
  (maintainer read-only:)
  (author read-only:)
  (homepage read-only:)
  (description read-only:)
  (keywords read-only:)
  (license read-only:)

  (exported-modules read-only:)
  (default-module read-only:)
  (module-directory read-only:))

(define (parse-package-metadata form)
  (if (or (not (list? form))
          (not (eq? 'package (car form))))
      (error "Invalid package metadata" form))
  (let* ((tbl (list->table (cdr form)))

         (one
          (lambda (name pred? #!key require?)
            (let ((lst (table-ref tbl name #f)))
              (if (and require? (not lst))
                  (error "Package attribute required:" name))
              (and lst
                   (if (or (not (pair? lst))
                           (not (null? (cdr lst)))
                           (not (pred? (car lst))))
                       (error "Invalid package metadata"
                              (list name lst))
                       (car lst))))))
         (list
          (lambda (name pred?)
            (let ((lst (table-ref tbl name #f)))
              (and lst
                   (if (or (not (list? lst))
                           (find-one? (lambda (x) (not (pred? x)))
                                      lst))
                       (error "Invalid package metadata"
                              (list name lst))
                       lst))))))
    (make-package-metadata
     (let ((v (symbol->version (one 'version symbol? require?: #t))))
       (if (not (version-build v))
           (error "Complete version required" (version->symbol v)))
       v)
     (one 'maintainer string?)
     (one 'author string?)
     (one 'homepage string?)
     (one 'description string?)
     (list 'keywords symbol?)
     (list 'license symbol?)
     
     (list 'exported-modules symbol?)
     (one 'default-module symbol?)
     (or (one 'module-directory string?)
         ""))))

(define (load-package-metadata fn)
  (with-input-from-file fn
    (lambda ()
      (parse-package-metadata (read)))))


;;; Packages

(define pkgfile-name
  "pkgfile")

(define-type package
  id: EC2E4078-EDCA-4BE4-B81E-2B60468F042D
  
  (name read-only:)
  (version read-only:)
  (dir read-only:)
  (metadata package-metadata/internal
            package-metadata-set!
            init: #f))

(define (package<? a b)
  (let ((a-name (package-name a))
        (b-name (package-name b)))
    (or (string<? a-name b-name)
        (and (string=? a-name b-name)
             (version<? (package-version a)
                        (package-version b))))))

(define (package-metadata ip)
  (let ((md (package-metadata/internal ip)))
    (or md
        (let* ((pkg-filename (path-expand
                              "pkgfile"
                              (package-dir ip)))
               (md (if (file-exists? pkg-filename)
                       (load-package-metadata
                        pkg-filename)
                       (error "Pkgfile does not exist:"
                              pkg-filename))))
          (package-metadata-set! ip md)
          md))))

(define (package-installed? p)
  (and (package-dir p) #t))

(define (make-noninstalled-package name metadata)
  (let ((pkg (make-package name
                           (package-metadata-version metadata)
                           #f)))
    (package-metadata-set! pkg metadata)))


;;; Remote packages

(define (load-remote-packages)
  ;; TODO
  '(("sack"
     ("http://...."
      (package
       (version v0.1.1)
       (maintainer "Per Eckerdal <per dot eckerdal at gmail dot com>")
       (author "Per Eckerdal <per dot eckerdal at gmail dot com>")
       (homepage "http://example.com")
       (description "An example package")
       (keywords example i/o)
       (license lgpl/v2.1 mit)

       (exported-modules server
                         lala
                         hello/duh)
       (default-module lala)
       (module-directory "src")
       
       (depends
        (sack (>= v1))
        pregexp))))))

(define (parse-remote-package-list package-list)
  (list->table
   (map (lambda (package)
          (cons
           (car package)
           (map (lambda (package-version-desc)
                  (if (not (= 2 (length package-version-desc)))
                      (error "Invalid package version descriptor"
                             package-version-desc))
                  (cons (car package-version-desc)
                        (parse-package-metadata
                         (cadr package-version-desc))))
             (cdr package))))
     package-list)))

(define get-remote-packages
  (let ((*remote-packages* #f))
    (lambda ()
      (or *remote-packages*
          (let ((rp (load-remote-packages)))
            (set! *remote-packages* rp)
            rp)))))

;;; Local packages


(define local-packages-dir
  ;; TODO
  "/Users/per/prog/gambit/blackhole/work/pkgs")

(define (load-installed-packages #!optional
                                 (pkgs-dir local-packages-dir))
  (let ((pkg-dirs
         (filter (lambda (x)
                   (is-directory? (path-expand x pkgs-dir)))
                 (if (file-exists? pkgs-dir)
                     (directory-files pkgs-dir)
                     '()))))
    (list->tree
     (map (lambda (pkg-dir)
            (let ((version-str
                   (last (string-split #\- pkg-dir))))
              (if (= (string-length version-str)
                     (string-length pkg-dir))
                  (error "Invalid package directory name" pkg-dir))
              (let ((version
                     (string->version
                      (last (string-split #\- pkg-dir))
                      force-complete?: #t))
                    (pkg-name
                     (substring pkg-dir
                                0
                                (- (string-length pkg-dir)
                                   (string-length version-str)
                                   1))))
                (make-package
                 pkg-name
                 version
                 (path-expand pkg-dir pkgs-dir)))))
       pkg-dirs)
     package<?)))

(define get-installed-packages
  (let ((*installed-packages* #f))
    (lambda ()
      (or *installed-packages*
          (let ((ip (load-installed-packages)))
            (set! *installed-packages* ip)
            ip)))))


;;; Module loader and resolver

(define *loaded-packages* (make-table))

(define (find-suitable-package pkg-name
                               #!optional
                               (version-exp #t)
                               (throw-error? #t))
  (let ((loaded-package (table-ref *loaded-packages* pkg-name #f)))
    (if loaded-package
        (if (version-match? (package-version loaded-package)
                            version-exp)
            loaded-package
            (and throw-error?
                 (error "A package is already loaded, with incompatible version:"
                        (package-version loaded-package)
                        version-exp)))
        (or (tree-backwards-fold-from
             (get-installed-packages)
             (make-package pkg-name
                                     (make-version 'max))
             package<?
             #f
             (lambda (p accum k)
               (cond
                ((not (equal? (package-name p)
                              pkg-name))
                 #f)
                
                ((version-match? (package-version p)
                                 version-exp)
                 p)

                (else
                 (k #f)))))
            (error "No package with matching version is installed:"
                   pkg-name
                   version-exp)))))

(define (load-package! pkg)
  (let ((currently-loading (make-table))
        (name (package-name pkg))
        (version (package-version pkg)))
    (let loop ((pkg pkg))
      (cond
       ((table-ref *loaded-packages* name #f)
        'already-loaded)
       ((eq? 'loading (table-ref currently-loading name #f))
        (error "Circular package dependency" pkg))
       (else
        (table-set! currently-loading name 'loading)
        (let* ((other-pkg (table-ref *loaded-packages* name #f))
               (other-version (package-version other-pkg)))
          (if other-pkg
              (and other-pkg
                   (not (equal? other-version version)))
              (error "Another incompatible package version is already loaded:"
                     name
                     version
                     other-version))
          
          (for-each (lambda (dep)
                      (loop
                       (if (symbol? dep)
                           (find-suitable-package dep)
                           (find-suitable-package (car dep)
                                                  `(and
                                                    ,@(cdr dep))))))
            (package-metadata-dependencies
             (package-metadata pkg)))
          
          (table-set! *loaded-packages* name pkg))
        (table-set! currently-loading name 'loaded))))))

(define-type package-module-path
  id: FBE06A79-BD70-43BD-982E-F8F8606FBC22

  package
  id)

(define (package-module-path-path path)
  (path-normalize (string-append (symbol->string
                                  (package-module-path-id path))
                                 ".scm")
                  #f ;; Don't allow relative paths
                  (path-normalize
                   ;; This call to path-normalize ensures that the
                   ;; directory actually exists. Otherwise
                   ;; path-normalize might segfault.
                   (path-expand
                    (symbol->string
                     (package-module-path-id path))
                    (package-dir
                     (package-module-path-package path))))))

(define (package-module-resolver loader path relative pkg-name
                                 #!rest
                                 ids
                                 #!key
                                 (version #t))
  (if (not (eq? loader package-loader))
      (error "Internal error"))
  
  (let ((package (find-suitable-package pkg-name version)))
    (map (lambda (id)
           (make-module-reference
            package-loader
            (make-package-module-path package id)))
      ids)))

(define package-loader
  (make-loader
   name:
   'package

   path-absolute?:
   (lambda (p) #t)
   
   path-absolutize:
   (lambda (path #!optional ref)
     (if (not (package-module-path? ref))
         (error "Invalid parameters" ref))
     (make-package-module-path
      (string->symbol
       (remove-dot-segments
        (string-append (symbol->string (package-module-path-id ref))
                       "/"
                       (symbol->string path))))
      (package-module-path-package ref)))
   
   load-module:
   (lambda (path)
     (let* ((ref (make-module-reference package-loader path))
            (actual-path (package-module-path-path path)))
       (let ((invoke-runtime
              invoke-compiletime
              visit
              info-alist
              (load-module-from-file ref
                                     actual-path)))
         (make-loaded-module
          invoke-runtime: invoke-runtime
          invoke-compiletime: invoke-compiletime
          visit: visit
          info: (make-module-info-from-alist ref info-alist)
          stamp: (path->stamp actual-path)
          reference: ref))))

   compare-stamp:
   (lambda (path stamp)
     (= (path->stamp (package-module-path-path path))
        stamp))

   module-name:
   (lambda (path)
     (path-strip-directory
      (cond ((symbol? path)
             (symbol->string path))
            ((package-module-path? path)
             (package-module-path-path path))
            (else
             (error "Invalid path" path)))))))


;;; Package installation and uninstallation

