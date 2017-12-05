(defpackage :lem-vi-mode.ex-parser
  (:use :cl :esrap :lem-vi-mode.ex-util)
  (:export :parse-ex))
(in-package :lem-vi-mode.ex-parser)

(defrule whitespace (* #\space)
  (:constant nil))

(defrule number (+ (or #\0 #\1 #\2 #\3 #\4 #\5 #\6 #\7 #\8 #\9))
  (:lambda (digits)
    (parse-integer (format nil "~{~D~}" digits))))

(defrule goto-line number
  (:lambda (number)
    `(lem-vi-mode.ex-command:goto-line ,number)))

(defrule current-line #\.
  (:lambda (x)
    (declare (ignore x))
    '(lem-vi-mode.ex-command:current-line)))

(defrule last-line #\$
  (:lambda (x)
    (declare (ignore x))
    '(lem-vi-mode.ex-command:last-line)))

(defrule marker (and #\' character)
  (:lambda (list)
    `(lem-vi-mode.ex-command:marker ,(second list))))

(defun is-not (a b)
  (not (eql a b)))

(defun not-/ (char)
  (is-not char #\/))

(defun not-? (char)
  (is-not char #\?))

(defrule escape-slash (and #\\ #\/)
  (:constant #\/))

(defrule forward-pattern-char
    (or escape-slash
        (not-/ character)))

(defrule forward-pattern (and #\/ (* forward-pattern-char) (? #\/))
  (:lambda (list)
    `(lem-vi-mode.ex-command:search-forward
      ,(coerce (second list) 'string))))

(defrule escape-question (and #\\ #\?)
  (:constant #\?))

(defrule backward-pattern-char
    (or escape-question
        (not-? character)))

(defrule backward-pattern (and #\? (* backward-pattern-char) (? #\?))
  (:lambda (list)
    `(lem-vi-mode.ex-command:search-backward
      ,(coerce (second list) 'string))))

(defrule offset-line (and (or #\+ #\-) number)
  (:lambda (list)
    `(lem-vi-mode.ex-command:offset-line
      ,(if (string= "-" (first list))
           (- (second list))
           (second list)))))

(defrule ex-line (and whitespace (or goto-line current-line last-line marker
                                           forward-pattern backward-pattern offset-line))
  (:lambda (list)
    (second list)))

(defrule ex-lines (+ ex-line)
  (:lambda (list)
    (if (null (rest list))
        (first list)
        `(progn . ,list))))

(defrule delimiter (or #\, #\;)
  (:lambda (x)
    (when (string= x ";")
      #\;)))

(defrule ex-range-lines (* (or (and ex-lines delimiter) (and ex-lines (? #\;))))
  (:lambda (list)
    (when list
      `(lem-vi-mode.ex-command:range
        ,@(loop :for (lines delim) :in list
                :collect `(lem:copy-point
                           ,(if (eql delim #\;)
                                `(lem-vi-mode.ex-command:goto-current-point ,lines)
                                lines)
                           :temporary))))))

(defrule ex-range-% #\%
  (:constant '(lem-vi-mode.ex-command:all-lines)))

(defrule ex-range (or ex-range-% ex-range-lines))

(defrule command-char (or (alphanumericp character) #\_)
  (:lambda (x)
    (if (equal x "_")
        #\_
        x)))

(defrule ex-command (or (+ (or #\~ #\& #\* #\@ #\< #\> #\= #\:))
                              (+ (or command-char #\-))
                              #\!)
  (:lambda (x)
    (if (equal x "!")
        x
        (coerce x 'string))))

(defrule ex-argument (+ character)
  (:lambda (chars)
    (coerce chars 'string)))

(defrule ex (and (? ex-range)
                 (? whitespace)
                 (? (and ex-command
                         (? whitespace)
                         (? ex-argument)
                         (? whitespace))))
  (:lambda (list)
    (let ((range (first list))
          (command (first (third list)))
          (argument (alexandria:when-let ((argument (third (third list))))
                      (string-trim " " argument))))
      (if (null command)
          `(lem-vi-mode.ex-command:goto-current-point ,range)
          `(lem-vi-mode.ex-command:call-ex-command ,range ,command ,(or argument ""))))))

(defun parse-ex (string)
  (ignore-errors (parse 'ex string)))
