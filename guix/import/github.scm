;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2016 Ben Woodcroft <donttrustben@gmail.com>
;;; Copyright © 2017-2020, 2022 Ludovic Courtès <ludo@gnu.org>
;;; Copyright © 2018 Eric Bavier <bavier@member.fsf.org>
;;; Copyright © 2019 Arun Isaac <arunisaac@systemreboot.net>
;;; Copyright © 2019 Efraim Flashner <efraim@flashner.co.il>
;;; Copyright © 2022 Maxime Devos <maximedevos@telenet.be>
;;; Copyright © 2022 Hartmut Goebel <h.goebel@crazy-compilers.com>
;;; Copyright © 2023 Giacomo Leidi <goodoldpaul@autistici.org>
;;; Copyright © 2024 Maxim Cournoyer <maxim.cournoyer@gmail.com>
;;;
;;; This file is part of GNU Guix.
;;;
;;; GNU Guix is free software; you can redistribute it and/or modify it
;;; under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 3 of the License, or (at
;;; your option) any later version.
;;;
;;; GNU Guix is distributed in the hope that it will be useful, but
;;; WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with GNU Guix.  If not, see <http://www.gnu.org/licenses/>.

(define-module (guix import github)
  #:use-module (ice-9 match)
  #:use-module (ice-9 regex)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-26)
  #:use-module (srfi srfi-34)
  #:use-module (srfi srfi-71)
  #:use-module ((guix import utils) #:select (find-version))
  #:use-module ((guix utils) #:select (string-replace-substring))
  #:use-module (guix i18n)
  #:use-module (guix diagnostics)
  #:use-module ((guix ui) #:select (display-hint))
  #:use-module ((guix download) #:prefix download:)
  #:use-module ((guix git-download) #:prefix download:)
  #:autoload   (guix build download) (open-connection-for-uri)
  #:use-module (json)
  #:use-module (guix packages)
  #:use-module (guix upstream)
  #:use-module (guix http-client)
  #:use-module (web uri)
  #:export (%github-api %github-updater))

;; For tests.
(define %github-api (make-parameter "https://api.github.com"))

(define (find-extension url)
  "Return the extension of the archive e.g. '.tar.gz' given a URL, or
false if none is recognized"
  (find (lambda (x) (string-suffix? x url))
        (list ".tar.gz" ".tar.bz2" ".tar.xz" ".zip" ".tar"
              ".tgz" ".tbz" ".love")))

(define (updated-github-url old-package new-version)
  ;; Return a url for the OLD-PACKAGE with NEW-VERSION.  If no source url in
  ;; the OLD-PACKAGE is a GitHub url, then return false.

  (define (updated-url url)
    (if (string-prefix? "https://github.com/" url)
        (let ((ext     (or (find-extension url) ""))
              (name    (package-upstream-name old-package))
              (version (package-version old-package))
              (prefix  (string-append "https://github.com/"
                                      (github-user-slash-repository url)))
              (repo    (github-repository url)))
          (cond
           ((string-suffix? (string-append "/tarball/v" version) url)
            (string-append prefix "/tarball/v" new-version))
           ((string-suffix? (string-append "/tarball/" version) url)
            (string-append prefix "/tarball/" new-version))
           ((string-suffix? (string-append "/archive/v" version ext) url)
            (string-append prefix "/archive/v" new-version ext))
           ((string-suffix? (string-append "/archive/" version ext) url)
            (string-append prefix "/archive/" new-version ext))
           ((string-suffix? (string-append "/archive/" name "-" version ext)
                            url)
            (string-append prefix "/archive/" name "-" new-version ext))
           ((string-suffix? (string-append "/releases/download/v" version "/"
                                           name "-" version ext)
                            url)
            (string-append prefix "/releases/download/v" new-version "/" name
                           "-" new-version ext))
           ((string-suffix? (string-append "/releases/download/" version "/"
                                           name "-" version ext)
                            url)
            (string-append prefix "/releases/download/" new-version "/" name
                           "-" new-version ext))
           ((string-suffix? (string-append "/releases/download/" version "/"
                                           repo "-" version ext)
                            url)
            (string-append prefix "/releases/download/" new-version "/" repo
                           "-" new-version ext))
           ((string-suffix? (string-append "/releases/download/" repo "-"
                                           version "/" repo "-" version ext)
                            url)
            (string-append prefix "/releases/download/" repo "-" new-version "/"
                           repo "-" new-version ext))
           ((string-match (string-append "/releases/download/(v)?" version "/"
                                         name ".*" ext "$")
                          url)
            (string-replace-substring url version new-version))

           (#t #f))) ; Some URLs are not recognised.
        #f))

  (match (package-source old-package)
    ((? origin? origin)
     (let ((source-uri   (origin-uri origin))
           (fetch-method (origin-method origin)))
       (cond
        ((eq? fetch-method download:url-fetch)
         (match source-uri
           ((? string?)
            (updated-url source-uri))
           ((source-uri ...)
            (find updated-url source-uri))))
        ((and (eq? fetch-method download:git-fetch)
              (string-prefix? "https://github.com/"
                              (download:git-reference-url source-uri)))
         (download:git-reference-url source-uri))
        (else #f))))
    (_ #f)))

(define (github-package? package)
  "Return true if PACKAGE is a package from GitHub, else false."
  (->bool (updated-github-url package "dummy")))

(define (github-repository url)
  "Return a string e.g. bedtools2 of the name of the repository, from a string
URL of the form 'https://github.com/arq5x/bedtools2/archive/v2.24.0.tar.gz'"
  (match (string-split (uri-path (string->uri url)) #\/)
    ((_ owner project . rest)
     (string-append (basename project ".git")))))

(define (github-user-slash-repository url)
  "Return a string e.g. arq5x/bedtools2 of the owner and the name of the
repository separated by a forward slash, from a string URL of the form
'https://github.com/arq5x/bedtools2/archive/v2.24.0.tar.gz'"
  (match (string-split (uri-path (string->uri url)) #\/)
    ((_ owner project . rest)
     (string-append owner "/" (basename project ".git")))))

(define %github-token
  ;; Token to be passed to Github.com to avoid the 60-request per hour
  ;; limit, or #f.
  (make-parameter (getenv "GUIX_GITHUB_TOKEN")))

(define %rate-limit-reset-time
  ;; Time (seconds since the Epoch, UTC) when the rate limit for GitHub
  ;; requests will be reset, or #f if the rate limit hasn't been reached.
  #f)

(define (update-rate-limit-reset-time! headers)
  "Update the rate limit reset time based on HEADERS, the HTTP response
headers."
  (match (assq-ref headers 'x-ratelimit-reset)
    ((= string->number (? number? reset))
     (set! %rate-limit-reset-time reset)
     reset)
    (_
     ;; This shouldn't happen.
     (warning
      (G_ "GitHub HTTP response lacks 'X-RateLimit-Reset' header~%"))
     0)))

(define (request-rate-limit-reached?)
  "Return true if the rate limit has been reached."
  (and %rate-limit-reset-time
       (match (< (car (gettimeofday)) %rate-limit-reset-time)
         (#t #t)
         (#f
          (set! %rate-limit-reset-time #f)
          #f))))

(define (fetch-releases-or-tags url)
  "Fetch the list of \"releases\" or, if it's empty, the list of tags for the
repository at URL.  Return the corresponding JSON dictionaries (alists),
or #f if the information could not be retrieved.

We look at both /releases and /tags because the \"release\" feature of GitHub
is little used; often, people simply provide a tag.  What's confusing is that
tags show up in the \"Releases\" tab of the web UI.  For instance,
'https://github.com/aconchillo/guile-json/releases' shows a number of
\"releases\" (really: tags), whereas
'https://api.github.com/repos/aconchillo/guile-json/releases' returns the
empty list."
  (define release-url
    (string-append (%github-api) "/repos/"
                   (github-user-slash-repository url)
                   "/releases"))
  (define tag-url
    (string-append (%github-api) "/repos/"
                   (github-user-slash-repository url)
                   "/tags"))

  (define headers
    ;; Ask for version 3 of the API as suggested at
    ;; <https://developer.github.com/v3/>.
    `((Accept . "application/vnd.github.v3+json")
      (user-agent . "GNU Guile")
      ,@(if (%github-token)
            `((Authorization . ,(string-append "token " (%github-token))))
            '())))

  (and (not (request-rate-limit-reached?))
       (guard (c ((and (http-get-error? c)
                       (= 404 (http-get-error-code c)))
                  (warning (G_ "~a is unreachable (~a)~%")
                           (uri->string (http-get-error-uri c))
                           (http-get-error-code c))
                  '#())                           ;return an empty release set
                 ((and (http-get-error? c)
                       (= 403 (http-get-error-code c)))
                  ;; See
                  ;; <https://docs.github.com/en/rest/overview/resources-in-the-rest-api#rate-limiting>.
                  (match (assq-ref (http-get-error-headers c)
                                   'x-ratelimit-remaining)
                    (#f
                     (raise c))
                    ((? (compose zero? string->number))
                     (let ((reset (update-rate-limit-reset-time!
                                   (http-get-error-headers c))))
                       (warning (G_ "GitHub rate limit exceeded; \
disallowing requests for ~a seconds~%")
                                (- reset (car (gettimeofday))))
                       (display-hint (G_ "You can raise the rate limit by
setting the @env{GUIX_GITHUB_TOKEN} environment variable to a token obtained
from @url{https://github.com/settings/tokens} with your GitHub account.

Alternatively, you can wait until your rate limit is reset, or use the
@code{generic-git} updater instead."))
                       #f))                       ;bail out
                    (_
                     (raise c)))))

         (let ((release-uri (string->uri release-url)))
           (call-with-port (open-connection-for-uri release-uri)
             (lambda (connection)
               (let* ((result (json->scm
                               (http-fetch release-uri
                                           #:port connection
                                           #:keep-alive? #t
                                           #:headers headers))))
                 (match result
                   (#()
                    ;; We got the empty list, presumably because the user
                    ;; didn't use GitHub's "release" mechanism, but hopefully
                    ;; they did use Git tags.
                    (json->scm (http-fetch tag-url
                                           #:port connection
                                           #:keep-alive? #t
                                           #:headers headers)))
                   (x x)))))))))

(define* (get-package-tags package)
  "Return an alist of tags keyed by their version for PACKAGE, a <package>
object."
  (define (github-uri uri)
    (match uri
      ((? string? url)
       url)                             ;surely a github.com URL
      ((? download:git-reference? ref)
       (download:git-reference-url ref))
      ((urls ...)
       (find (cut string-contains <> "github.com") urls))))

  (define (pre-release? x)
    (assoc-ref x "prerelease"))

  (define source-uri
    (github-uri (origin-uri (package-source package))))

  ;; This procedure returns (version . tag) pair, or #f
  ;; if RELEASE doesn't seyem to correspond to a version.
  (define (release->version release)
    (let* ((tag (or (assoc-ref release "tag_name") ;a "release"
                    (assoc-ref release "name")))   ;a tag
           (name (package-upstream-name package))
           (name-length (string-length name)))
      (cond
       ;; Some tags include the name of the package e.g. "fdupes-1.51"; remove
       ;; these.
       ((and (< name-length (string-length tag))
             (string=? (string-append name "-")
                       (substring tag 0 (+ name-length 1))))
        (cons (substring tag (+ name-length 1)) tag))
       ;; Some tags start with a "v" e.g. "v0.25.0" or with the word "version"
       ;; e.g. "version.2.1" where some are just the version number.
       ((string-prefix? "version" tag)
        (cons (if (char-set-contains? char-set:digit (string-ref tag 7))
                  (substring tag 7)
                  (substring tag 8)) tag))
       ((string-prefix? "v" tag)
        (cons (substring tag 1) tag))
       ;; Finally, reject tags that don't start with a digit:
       ;; they may not represent a release.
       ((and (not (string-null? tag))
             (char-set-contains? char-set:digit
                                 (string-ref tag 0)))
        (cons tag tag))
       (else #f))))

  (match (and=> (fetch-releases-or-tags source-uri) vector->list)
    (#f '())
    (json
     (filter-map release->version
                 (match (remove pre-release? json)
                   (() json)      ;keep everything
                   (releases releases))))))

(define* (import-release pkg #:key version partial-version?)
  "Return an <upstream-source> for the latest release of PKG.
Optionally include a VERSION string to fetch a specific version, which may be
a partial version prefix if PARTIAL-VERSION? is #t."
  (let* ((original-uri (origin-uri (package-source pkg)))
         (tags (get-package-tags pkg))
         (versions (map car tags))
         (version (find-version versions version partial-version?))
         (tag (assoc-ref tags version)))
    (and version
         (upstream-source
          (package (package-upstream-name pkg))
          (version version)
          (urls (if (download:git-reference? original-uri)
                    (download:git-reference
                     (inherit original-uri)
                     (commit tag))
                    (list (updated-github-url pkg version))))))))

(define %github-updater
  (upstream-updater
   (name 'github)
   (description "Updater for GitHub packages")
   (pred github-package?)
   (import import-release)))
