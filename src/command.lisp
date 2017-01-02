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
          indent
          newline-and-indent
          indent-region
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
        (insert-character (current-point) c n)
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
             (insert-character (current-point) #\newline 1))
            ((char= c C-d)
             (delete-character (current-point) 1 nil))
            (t
             (insert-character (current-point) c 1))))))

(define-key *global-keymap* (kbd "C-m") 'newline)
(define-command newline (&optional (n 1)) ("p")
  (insert-character (current-point) #\newline n))

(define-key *global-keymap* (kbd "C-o") 'open-line)
(define-command open-line (n) ("p")
  (let ((point (current-point)))
    (insert-character (current-point) #\newline n)
    (character-offset point (- n))))

(define-key *global-keymap* (kbd "C-d") 'delete-next-char)
(define-key *global-keymap* (kbd "[dc]") 'delete-next-char)
(define-command delete-next-char (&optional n) ("P")
  (when (eobp)
    (editor-error "End of buffer"))
  (when n
    (unless (continue-flag :kill)
      (kill-ring-new)))
  (delete-character (current-point)
		    (or n 1)
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
  (setf end (copy-point end :temporary))
  (unless (continue-flag :kill)
    (kill-ring-new))
  (move-point (current-point) start)
  (delete-character (current-point) (count-characters start end) t)
  t)

(define-key *global-keymap* (kbd "C-k") 'kill-line)
(define-command kill-line (&optional (n 1)) ("p")
  (kill-region (copy-point (current-point) :temporary)
               (dotimes (_ n (current-point))
                 (cond ((eolp)
                        (next-line 1)
                        (beginning-of-line))
                       (t
                        (end-of-line))))))

(define-key *global-keymap* (kbd "C-y") 'yank)
(define-command yank (n) ("p")
  (let ((string (kill-ring-nth n)))
    (setf (get-bvar :yank-start) (copy-point (current-point) :temporary))
    (insert-string (current-point) string)
    (setf (get-bvar :yank-end) (copy-point (current-point) :temporary))
    (continue-flag :yank)
    t))

(define-key *global-keymap* (kbd "M-y") 'yank-pop)
(define-command yank-pop (&optional n) ("p")
  (let ((start (get-bvar :yank-start))
        (end (get-bvar :yank-end))
        prev-yank-p)
    (when (continue-flag :yank) (setq prev-yank-p t))
    (cond ((and start end prev-yank-p)
           (delete-between-points start end)
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
            (move-to-column (current-point) *next-line-prev-column*))
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
  (let ((bol (line-start (copy-point (current-point) :temporary))))
    (or (text-property-at (current-point) :field -1)
        (previous-single-property-change (current-point)
                                         :field
                                         bol)
        (move-point (current-point) bol)))
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
      (cond
        ((line-offset (current-point)
                      (1- (window-height (current-window))))
         (window-recenter (current-window))
         t)
        (t
         (buffer-end (current-point))
         (window-recenter (current-window))
         t))))

(define-key *global-keymap* (kbd "M-v") 'prev-page)
(define-key *global-keymap* (kbd "[ppage]") 'prev-page)
(define-command prev-page (&optional n) ("P")
  (if n
      (scroll-up n)
      (cond
        ((line-offset (current-point)
                      (- (1- (window-height (current-window)))))
         (window-recenter (current-window))
         t)
        (t
         (buffer-start (current-point))
         (window-recenter (current-window))
         t))))

(defun tab-line-aux (n make-space-str)
  (dotimes (_ n t)
    (let ((count (save-excursion
                   (back-to-indentation)
                   (current-column))))
      (multiple-value-bind (div mod)
          (floor count (tab-size))
        (beginning-of-line)
        (delete-while-whitespaces t nil)
        (insert-string (current-point) (funcall make-space-str div))
        (insert-character (current-point) #\space mod)))
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
    (unless (search-forward (current-point) (string #\page))
      (end-of-buffer)
      (return nil))))

(define-key *global-keymap* (kbd "C-x [") 'prev-page-char)
(define-command prev-page-char (&optional (n 1)) ("p")
  (dotimes (_ n t)
    (when (eql (char-code #\page) (preceding-char))
      (shift-position -1))
    (unless (search-backward (current-point) (string #\page))
      (beginning-of-buffer)
      (return nil))))

(define-key *global-keymap* (kbd "C-x C-o") 'delete-blank-lines)
(define-command delete-blank-lines () ()
  (let ((point (current-point)))
    (loop
       (unless (blank-line-p point)
	 (line-offset point 1)
	 (return))
       (unless (line-offset point -1)
	 (return)))
    (loop
       (when (end-buffer-p point)
	 (return))
       (let ((nblanks (blank-line-p point)))
	 (if nblanks
	     (delete-character point nblanks)
	     (return))))))

(define-key *global-keymap* (kbd "M-Spc") 'just-one-space)
(define-command just-one-space () ()
  (skip-chars-backward (current-point) '(#\space #\tab))
  (delete-while-whitespaces t nil)
  (insert-character (current-point) #\space 1)
  t)

(define-key *global-keymap* (kbd "M-^") 'delete-indentation)
(define-command delete-indentation () ()
  (let* ((cur (current-point))
         (prev (copy-point (line-start cur) :temporary)))
    (when (line-offset cur -1)
      (delete-between-points (line-end cur) prev)
      (just-one-space))
    t))

(define-key *global-keymap* (kbd "C-t") 'transpose-characters)
(define-command transpose-characters () ()
  (let ((point (current-point)))
    (cond ((start-line-p point))
          ((end-line-p point)
           (let ((c1 (character-at point -1))
                 (c2 (character-at point -2)))
             (unless (eql c2 #\newline)
               (delete-character point -2)
               (insert-string point (format nil "~C~C" c1 c2)))))
          (t
           (let ((c1 (character-at point 0))
                 (c2 (character-at point -1)))
             (delete-character point 1)
             (delete-character point -1)
             (insert-string point (format nil "~C~C" c1 c2)))))))

(define-key *global-keymap* (kbd "M-m") 'back-to-indentation)
(define-command back-to-indentation () ()
  (let ((point (current-point)))
    (skip-chars-forward (line-start point)
                        '(#\space #\tab)))
  t)

(define-key *global-keymap* (kbd "C-\\") 'undo)
(define-command undo (n) ("p")
  (dotimes (_ n t)
    (let ((point (buffer-undo (current-buffer))))
      (if point
          (move-point (current-point) point)
          (editor-error "Undo Error")))))

(define-key *global-keymap* (kbd "C-_") 'redo)
(define-command redo (n) ("p")
  (dotimes (_ n t)
    (let ((point (buffer-redo (current-buffer))))
      (if point
          (move-point (current-point) point)
          (editor-error "Redo Error")))))

(define-key *global-keymap* (kbd "C-@") 'mark-set)
(define-command mark-set () ()
  (set-current-mark (current-point))
  (message "Mark set"))

(define-key *global-keymap* (kbd "C-x C-x") 'exchange-point-mark)
(define-command exchange-point-mark () ()
  (check-marked)
  (let ((mark (buffer-mark (current-buffer)))
        (point (copy-point (buffer-point (current-buffer)) :temporary)))
    (move-point (current-point) mark)
    (set-current-mark point))
  t)

(define-key *global-keymap* (kbd "M-g") 'goto-line)
(define-command goto-line (n) ("nLine to GOTO: ")
  (cond ((< n 1)
         (setf n 1))
        ((< #1=(buffer-nlines (current-buffer)) n)
         (setf n #1#)))
  (line-offset (buffer-start (current-point)) (1- n))
  t)

(define-key *global-keymap* (kbd "C-x #") 'filter-buffer)
(define-command filter-buffer (cmd) ("sFilter buffer: ")
  (let ((buffer (current-buffer)))
    (multiple-value-bind (start end)
        (cond ((buffer-mark-p buffer)
               (values (region-beginning buffer)
                       (region-end buffer)))
              (t
               (values (buffers-start buffer)
                       (buffers-end buffer))))
      (let ((string (points-to-string start end))
            output-value
            error-output-value
            status)
        (let ((output-string
               (with-output-to-string (output)
                 (with-input-from-string (input string)
                   (multiple-value-setq
		       (output-value error-output-value status)
		     (uiop:run-program (format nil "cd ~A; ~A" (buffer-directory buffer) cmd)
				       :input input
				       :output output
				       :error-output output
				       :ignore-error-status t))))))
          (delete-between-points start end)
          (insert-string start output-string)
          (message "~D ~A" status error-output-value)
          (zerop status))))))

(define-key *global-keymap* (kbd "C-x @") 'pipe-command)
(define-command pipe-command (str) ("sPipe command: ")
  (let ((directory (buffer-directory)))
    (with-pop-up-typeout-window (out (get-buffer-create "*Command*") :focus t :erase t)
      (uiop:run-program (format nil "cd ~A; ~A" directory str)
                        :output out
                        :error-output out
                        :ignore-error-status t))))

(define-key *global-keymap* (kbd "C-i") 'indent)
(define-command indent (&optional (n 1)) ("p")
  (if (get-bvar :calc-indent-function :buffer (current-buffer))
      (indent-line (current-point))
      (self-insert n)))

(define-key *global-keymap* (kbd "C-j") 'newline-and-indent)
(define-key *global-keymap* (kbd "M-j") 'newline-and-indent)
(define-command newline-and-indent (n) ("p")
  (newline n)
  (indent))

(define-key *global-keymap* (kbd "C-M-\\") 'indent-region)
(define-command indent-region (start end) ("r")
  (save-excursion
    (apply-region-lines start end 'indent)))

(define-command delete-trailing-whitespace () ()
  (save-excursion
    (beginning-of-buffer)
    (loop until (eobp) do
	 (loop
	    (end-of-line)
	    (let ((c (preceding-char)))
	      (if (or (equal c #\space)
		      (equal c #\tab))
		  (delete-character (current-point) -1 nil)
		  (return))))
	 (forward-line 1))
    (end-of-buffer)
    (delete-blank-lines)))
