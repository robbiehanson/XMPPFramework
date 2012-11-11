;;; punycode.el --- An ASCII compatible Unicode encoding format.

;; Copyright (C) 2003-2012 Simon Josefsson
;; Keywords: punycode, idna, idn, unicode, encoding

;; This file is part of GNU Libidn.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; A simple wrapper around the command line "idn" utility in GNU
;; Libidn to make punycode operations available in Emacs.

;; Example:
;;
;; (punycode-encode "räksmörgås")
;; => "rksmrgs-5wao1o"
;;
;; (punycode-encode "foo")
;; => "foo-"
;;
;; (punycode-decode "rksmrgs-5wao1o")
;; => "räksmörgås"
;;
;; (punycode-decode "foo-")
;; => "foo"

;; This package is useless unless your emacs has at least partial
;; support for the UTF-8 coding system.

;; Report bugs to bug-libidn@gnu.org.

;;; Code:

(defgroup punycode nil
  "Punycode: An ASCII compatible Unicode encoding format.")

(defcustom punycode-program "idn"
  "Name of the GNU Libidn \"idn\" application."
  :type 'string
  :group 'punycode)

(defcustom punycode-environment '("CHARSET=UTF-8")
  "List of environment variable definitions prepended to `process-environment'."
  :type '(repeat string)
  :group 'punycode)

(defcustom punycode-encode-parameters '("--quiet" "--punycode-encode")
  "Parameters passed to `punycode-program' to invoke punycode encoding mode."
  :type '(repeat string)
  :group 'punycode)

(defcustom punycode-decode-parameters '("--quiet" "--punycode-decode")
  "Parameters passed to `punycode-program' to invoke punycode decoding mode."
  :type '(repeat string)
  :group 'punycode)

;; Internal process handling:

(defvar punycode-encode-process nil
  "Internal variable holding process for punycode encoding.")
(defvar punycode-encode-response nil
  "Internal variable holding response data received from punycode process.")

(defun punycode-encode-response-clear ()
  (setq punycode-encode-response nil))

(defun punycode-encode-response ()
  (while (and (eq (process-status punycode-encode-process) 'run)
	      (null punycode-encode-response))
    (accept-process-output punycode-encode-process 1))
  punycode-encode-response)

(defun punycode-encode-filter (process string)
  (setq punycode-encode-response (concat punycode-encode-response string)))

(defun punycode-encode-process ()
  (if (and punycode-encode-process
	   (eq (process-status punycode-encode-process) 'run))
      punycode-encode-process
    (if punycode-encode-process
	(condition-case ()
	    (kill-process punycode-encode-process)
	  (error)))
    (when (setq punycode-encode-process
		(let ((process-environment (append punycode-environment
						   process-environment)))
		  (apply 'start-process "punycode" nil punycode-program
			 punycode-encode-parameters)))
      (set-process-filter punycode-encode-process 'punycode-encode-filter)
      (set-process-coding-system punycode-encode-process 'utf-8 'utf-8)
      (process-kill-without-query punycode-encode-process))
    punycode-encode-process))

(defvar punycode-decode-process nil
  "Internal variable holding process for punycode encoding.")
(defvar punycode-decode-response nil
  "Internal variable holding response data received from punycode process.")

(defun punycode-decode-response-clear ()
  (setq punycode-decode-response nil))

(defun punycode-decode-response ()
  (while (and (eq (process-status punycode-decode-process) 'run)
	      (null punycode-decode-response))
    (accept-process-output punycode-decode-process 1))
  punycode-decode-response)

(defun punycode-decode-filter (process string)
  (setq punycode-decode-response (concat punycode-decode-response string)))

(defun punycode-decode-process ()
  (if (and punycode-decode-process
	   (eq (process-status punycode-decode-process) 'run))
      punycode-decode-process
    (if punycode-decode-process
	(condition-case ()
	    (kill-process punycode-decode-process)
	  (error)))
    (when (setq punycode-decode-process
		(let ((process-environment (append punycode-environment
						   process-environment)))
		  (apply 'start-process "punycode" nil punycode-program
			 punycode-decode-parameters)))
      (set-process-filter punycode-decode-process 'punycode-decode-filter)
      (set-process-coding-system punycode-decode-process 'utf-8 'utf-8)
      (process-kill-without-query punycode-decode-process))
    punycode-decode-process))

;; Punycode Elisp API:

(defun punycode-encode (str)
  "Returns a Punycode encoding of STR."
  (let ((proc (punycode-encode-process))
	string)
    (if (null proc)
	(error "Cannot start idn application")
      (punycode-encode-response-clear)
      (process-send-string proc (concat str "\n"))
      (setq string (punycode-encode-response))
      (if (and string (string= (substring string (1- (length string))) "\n"))
	  (substring string 0 (1- (length string)))
	string))))

(defun punycode-decode (str)
  "Returns a possibly multibyte string which is the punycode decoding of STR."
  (let ((proc (punycode-decode-process))
	string)
    (if (null proc)
	(error "Cannot start idn application")
      (punycode-decode-response-clear)
      (process-send-string proc (concat str "\n"))
      (setq string (punycode-decode-response))
      (if (and string (string= (substring string (1- (length string))) "\n"))
	  (substring string 0 (1- (length string)))
	string))))

(defun punycode-shutdown ()
  "Kill the punycode related process."
  (interactive)
  (if (and punycode-decode-process
	   (eq (process-status punycode-decode-process) 'run))
      (kill-process punycode-decode-process))
  (if (and punycode-encode-process
	   (eq (process-status punycode-encode-process) 'run))
      (kill-process punycode-encode-process)))

(provide 'punycode)

;;; punycode.el ends here
