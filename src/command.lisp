(in-package :lem)

(export '(exit-lem
          quick-exit
          keyboard-quit
          universal-argument
          self-insert
          unmark-buffer
          toggle-read-only
          rename-buffer
          quoted-insert
          newline
          open-line
          delete-next-char
          delete-previous-char
          copy-region
          kill-region
          kill-line
          yank
          yank-pop
          next-line
          prev-line
          next-char
          prev-char
          move-to-beginning-of-buffer
          move-to-end-of-buffer
          move-to-beginning-of-line
          move-to-end-of-line
          next-page
          prev-page
          entab-line
          detab-line
          newline-and-indent
          next-page-char
          prev-page-char
          delete-blank-lines
          just-one-space
          delete-indentation
          transpose-characters
          back-to-indentation
          undo
          redo
          mark-set
          exchange-point-mark
          goto-line
          filter-buffer
          pipe-command
          delete-trailing-whitespace))

(define-key *global-keymap* (kbd "C-x C-c") 'exit-lem)
(define-command exit-lem () ()
  (when (or (not (any-modified-buffer-p))
            (minibuf-y-or-n-p "Modified buffers exist. Leave anyway"))
    (exit-editor)))

(define-command quick-exit () ()
  (save-some-buffers t)
  (exit-editor))

(define-key *global-keymap* (kbd "C-g") 'keyboard-quit)
(define-command keyboard-quit () ()
  (error 'editor-abort))

(define-key *global-keymap* (kbd "C-u") 'universal-argument)
(define-command universal-argument () ()
  (let ((numlist)
        n)
    (do ((c (minibuf-read-char "C-u 4")
            (minibuf-read-char
             (format nil "C-u ~{~a~}" numlist))))
        (nil)
      (cond
        ((char= c C-u)
         (setq numlist
               (mapcar 'digit-char-p
                       (coerce
                        (format nil "~a"
                                (* 4
                                   (if numlist
                                       (parse-integer
                                        (format nil "~{~a~}" numlist))
                                       4)))
                        'list))))
        ((and (char= c #\-) (null numlist))
         (setq numlist (append numlist (list #\-))))
        ((setq n (digit-char-p c))
         (setq numlist
               (append numlist (list n))))
        (t
         (unread-key c)
         (let ((arg (if numlist
                        (parse-integer (format nil "~{~a~}" numlist))
                        4)))
           (return (funcall (read-key-command)
                            arg))))))))

(define-command self-insert (n) ("p")
  (let ((c (insertion-key-p (last-read-key-sequence))))
    (if c
        (insert-char c n)
        (undefined-key))))

(define-key *global-keymap* (kbd "M-~") 'unmark-buffer)
(define-command unmark-buffer () ()
  (buffer-unmark (current-buffer))
  t)

(define-key *global-keymap* (kbd "C-x C-q") 'toggle-read-only)
(define-command toggle-read-only () ()
  (setf (buffer-read-only-p (current-buffer))
        (not (buffer-read-only-p (current-buffer))))
  t)

(define-command rename-buffer (name) ("sRename buffer: ")
  (buffer-rename (current-buffer) name)
  t)

(define-key *global-keymap* (kbd "C-q") 'quoted-insert)
(define-command quoted-insert (&optional (n 1)) ("p")
  (let ((c (read-key)))
    (dotimes (_ n t)
      (cond ((char= c C-m)
             (insert-newline 1))
            ((char= c C-d)
             (delete-char 1 nil))
            (t
             (insert-char c 1))))))

(define-key *global-keymap* (kbd "C-m") 'newline)
(define-command newline (&optional (n 1)) ("p")
  (insert-newline n))

(define-key *global-keymap* (kbd "C-o") 'open-line)
(define-command open-line (n) ("p")
  (insert-newline n)
  (shift-position (- n)))

(define-key *global-keymap* (kbd "C-d") 'delete-next-char)
(define-key *global-keymap* (kbd "[dc]") 'delete-next-char)
(define-command delete-next-char (&optional n) ("P")
  (when (eobp)
    (editor-error "End of buffer"))
  (when n
    (unless (continue-flag :kill)
      (kill-ring-new)))
  (delete-char (or n 1)
               (if n t nil)))

(define-key *global-keymap* (kbd "C-h") 'delete-previous-char)
(define-key *global-keymap* (kbd "[backspace]") 'delete-previous-char)
(define-key *global-keymap* (kbd "[del]") 'delete-previous-char)
(define-command delete-previous-char (&optional n) ("P")
  (prev-char (or n 1))
  (delete-next-char n))

(define-key *global-keymap* (kbd "M-w") 'copy-region)
(define-command copy-region (start end) ("r")
  (unless (continue-flag :kill)
    (kill-ring-new))
  (kill-push (points-to-string start end))
  (buffer-mark-cancel (current-buffer))
  t)

(define-key *global-keymap* (kbd "C-w") 'kill-region)
(define-command kill-region (start end) ("r")
  (setf end (copy-marker end :temporary))
  (unless (continue-flag :kill)
    (kill-ring-new))
  (move-point (current-marker) start)
  (delete-char (count-characters start end) t)
  t)

(define-key *global-keymap* (kbd "C-k") 'kill-line)
(define-command kill-line (&optional (n 1)) ("p")
  (kill-region (copy-marker (current-marker) :temporary)
               (dotimes (_ n (current-marker))
                 (cond ((eolp)
                        (next-line 1)
                        (beginning-of-line))
                       (t
                        (end-of-line))))))

(define-key *global-keymap* (kbd "C-y") 'yank)
(define-command yank (n) ("p")
  (let ((string (kill-ring-nth n)))
    (setf (get-bvar :yank-start) (current-point))
    (insert-string string)
    (setf (get-bvar :yank-end) (current-point))
    (continue-flag :yank)
    t))

(define-key *global-keymap* (kbd "M-y") 'yank-pop)
(define-command yank-pop (&optional n) ("p")
  (let ((start (get-bvar :yank-start))
        (end (get-bvar :yank-end))
        prev-yank-p)
    (when (continue-flag :yank) (setq prev-yank-p t))
    (cond ((and start end prev-yank-p)
           (delete-region start end)
           (kill-ring-rotate)
           (yank n))
          (t
           (message "Previous command was not a yank")
           nil))))

(defvar *next-line-prev-column* nil)

(define-key *global-keymap* (kbd "C-n") 'next-line)
(define-key *global-keymap* (kbd "[down]") 'next-line)
(define-command next-line (&optional n) ("p")
  (unless (continue-flag :next-line)
    (setq *next-line-prev-column* (current-column)))
  (unless (prog1 (forward-line n)
            (move-to-column (current-marker) *next-line-prev-column*))
    (cond ((plusp n)
           (end-of-buffer)
           (editor-error "End of buffer"))
          (t
           (beginning-of-buffer)
           (editor-error "Beginning of buffer"))))
  t)

(define-key *global-keymap* (kbd "C-p") 'prev-line)
(define-key *global-keymap* (kbd "[up]") 'prev-line)
(define-command prev-line (&optional n) ("p")
  (next-line (- n)))

(define-key *global-keymap* (kbd "C-f") 'next-char)
(define-key *global-keymap* (kbd "[right]") 'next-char)
(define-command next-char (&optional (n 1)) ("p")
  (or (shift-position n)
      (editor-error "End of buffer")))

(define-key *global-keymap* (kbd "C-b") 'prev-char)
(define-key *global-keymap* (kbd "[left]") 'prev-char)
(define-command prev-char (&optional (n 1)) ("p")
  (or (shift-position (- n))
      (editor-error "Beginning of buffer")))

(define-key *global-keymap* (kbd "M-<") 'move-to-beginning-of-buffer)
(define-command move-to-beginning-of-buffer () ()
  (beginning-of-buffer)
  t)

(define-key *global-keymap* (kbd "M->") 'move-to-end-of-buffer)
(define-command move-to-end-of-buffer () ()
  (end-of-buffer)
  t)

(define-key *global-keymap* (kbd "C-a") 'move-to-beginning-of-line)
(define-key *global-keymap* (kbd "[home]") 'move-to-beginning-of-line)
(define-command move-to-beginning-of-line () ()
  (let ((bol (line-start (copy-marker (current-marker) :temporary))))
    (or (text-property-at (current-marker) 'lem.property:field-separator -1)
        (previous-single-property-change (current-marker)
                                         'lem.property:field-separator
                                         bol)
        (move-point (current-marker) bol)))
  t)

(define-key *global-keymap* (kbd "C-e") 'move-to-end-of-line)
(define-key *global-keymap* (kbd "[end]") 'move-to-end-of-line)
(define-command move-to-end-of-line () ()
  (end-of-line)
  t)

(define-key *global-keymap* (kbd "C-v") 'next-page)
(define-key *global-keymap* (kbd "[npage]") 'next-page)
(define-command next-page (&optional n) ("P")
  (if n
      (scroll-down n)
      (let ((point (current-point)))
        (cond ((forward-line (1- (window-height (current-window))))
               (window-recenter (current-window))
               t)
              ((and (point-set point) nil))
              ((not (eobp))
               (end-of-buffer)
               (window-recenter (current-window))
               t)))))

(define-key *global-keymap* (kbd "M-v") 'prev-page)
(define-key *global-keymap* (kbd "[ppage]") 'prev-page)
(define-command prev-page (&optional n) ("P")
  (if n
      (scroll-up n)
      (let ((point (current-point)))
        (cond ((forward-line (- (1- (window-height (current-window)))))
               (window-recenter (current-window))
               t)
              ((and (point-set point) nil))
              ((not (bobp))
               (beginning-of-buffer)
               (window-recenter (current-window))
               t)))))

(defun tab-line-aux (n make-space-str)
  (dotimes (_ n t)
    (let ((count (save-excursion
                   (back-to-indentation)
                   (current-column))))
      (multiple-value-bind (div mod)
          (floor count (tab-size))
        (beginning-of-line)
        (delete-while-whitespaces t nil)
        (insert-string (funcall make-space-str div))
        (insert-char #\space mod)))
    (unless (forward-line 1)
      (return))))

(define-command entab-line (n) ("p")
  (tab-line-aux n
                #'(lambda (n)
                    (make-string n :initial-element #\tab))))

(define-command detab-line (n) ("p")
  (tab-line-aux n
                #'(lambda (n)
                    (make-string (* n (tab-size)) :initial-element #\space))))

(define-key *global-keymap* (kbd "C-x ]") 'next-page-char)
(define-command next-page-char (&optional (n 1)) ("p")
  (dotimes (_ n t)
    (when (eql (char-code #\page) (following-char))
      (shift-position 1))
    (unless (search-forward (current-marker) (string #\page))
      (end-of-buffer)
      (return nil))))

(define-key *global-keymap* (kbd "C-x [") 'prev-page-char)
(define-command prev-page-char (&optional (n 1)) ("p")
  (dotimes (_ n t)
    (when (eql (char-code #\page) (preceding-char))
      (shift-position -1))
    (unless (search-backward (current-marker) (string #\page))
      (beginning-of-buffer)
      (return nil))))

(define-key *global-keymap* (kbd "C-x C-o") 'delete-blank-lines)
(define-command delete-blank-lines () ()
  (do ()
      ((not (blank-line-p))
       (forward-line 1))
    (unless (forward-line -1)
      (return)))
  (do () ((eobp))
    (let ((result (blank-line-p)))
      (unless (and result (delete-char result nil))
        (return)))))

(define-key *global-keymap* (kbd "M-Spc") 'just-one-space)
(define-command just-one-space () ()
  (skip-chars-backward '(#\space #\tab))
  (delete-while-whitespaces t nil)
  (insert-char #\space 1)
  t)

(define-key *global-keymap* (kbd "M-^") 'delete-indentation)
(define-command delete-indentation () ()
  (beginning-of-line)
  (let ((point (current-point)))
    (forward-line -1)
    (end-of-line)
    (delete-char (region-count (current-point) point) nil)
    (just-one-space)
    t))

(define-key *global-keymap* (kbd "C-t") 'transpose-characters)
(define-command transpose-characters () ()
  (cond ((bolp))
        ((eolp)
         (let* ((c1 (char-before 1))
                (c2 (char-before 2)))
           (unless (eql c2 #\newline)
             (delete-char -2 nil)
             (insert-char c1 1)
             (insert-char c2 1))))
        (t
         (let* ((c1 (following-char))
                (c2 (preceding-char)))
           (delete-char 1 nil)
           (delete-char -1 nil)
           (insert-char c1 1)
           (insert-char c2 1)))))

(define-key *global-keymap* (kbd "M-m") 'back-to-indentation)
(define-command back-to-indentation () ()
  (beginning-of-line)
  (skip-chars-forward '(#\space #\tab))
  t)

(define-key *global-keymap* (kbd "C-\\") 'undo)
(define-command undo (n) ("p")
  (dotimes (_ n t)
    (let ((point (buffer-undo (current-buffer))))
      (if point
          (point-set point)
          (editor-error "Undo Error")))))

(define-key *global-keymap* (kbd "C-_") 'redo)
(define-command redo (n) ("p")
  (dotimes (_ n t)
    (let ((point (buffer-redo (current-buffer))))
      (if point
          (point-set point)
          (editor-error "Redo Error")))))

(define-key *global-keymap* (kbd "C-@") 'mark-set)
(define-command mark-set () ()
  (set-current-mark (current-marker))
  (message "Mark set"))

(define-key *global-keymap* (kbd "C-x C-x") 'exchange-point-mark)
(define-command exchange-point-mark () ()
  (check-marked)
  (let ((mark (buffer-mark-marker (current-buffer)))
        (point (copy-marker (buffer-point-marker (current-buffer)) :temporary)))
    (move-point (current-marker) mark)
    (set-current-mark point))
  t)

(define-key *global-keymap* (kbd "M-g") 'goto-line)
(define-command goto-line (n) ("nLine to GOTO: ")
  (setf n
        (if (< n 1)
            1
            (min n (buffer-nlines (current-buffer)))))
  (point-set (point-min))
  (forward-line (1- n))
  t)

(define-key *global-keymap* (kbd "C-x #") 'filter-buffer)
(define-command filter-buffer (str) ("sFilter buffer: ")
  (let (begin end)
    (cond ((buffer-mark-p)
           (setq begin (marker-point (region-beginning)))
           (setq end (marker-point (region-end))))
          (t
           (setq begin (point-min))
           (setq end (point-max))))
    (let ((input-string
           (region-string begin end))
          (outstr (make-array '(0)
                              :element-type 'character
                              :fill-pointer t))
          output-value
          error-output-value
          status)
      (with-output-to-string (output outstr)
        (with-input-from-string (input input-string)
          (multiple-value-setq (output-value error-output-value status)
                               (uiop:run-program (format nil "cd ~A; ~A" (buffer-directory) str)
                                                 :input input
                                                 :output output
                                                 :error-output output
                                                 :ignore-error-status t))))
      (delete-region begin end)
      (insert-string outstr)
      (point-set begin)
      (message "~D ~A" (write-to-string status) error-output-value)
      (zerop status))))

(define-key *global-keymap* (kbd "C-x @") 'pipe-command)
(define-command pipe-command (str) ("sPipe command: ")
  (let ((directory (buffer-directory)))
    (with-pop-up-typeout-window (out (get-buffer-create "*Command*") :focus t :erase t)
      (uiop:run-program (format nil "cd ~A; ~A" directory str)
                        :output out
                        :error-output out
                        :ignore-error-status t))))

(define-command delete-trailing-whitespace () ()
  (save-excursion
   (beginning-of-buffer)
   (loop until (eobp) do
     (loop
       (end-of-line)
       (let ((c (preceding-char)))
         (if (or (equal c #\space)
                 (equal c #\tab))
             (delete-char -1 nil)
             (return))))
     (forward-line 1))
   (end-of-buffer)
   (delete-blank-lines)))
