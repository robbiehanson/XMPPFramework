;;; idna.el --- Internationalizing Domain Names in Applications.

;; Copyright (C) 2003-2012 Simon Josefsson
;; Keywords: idna, idn, domain name, internationalization

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
;; Libidn to make IDNA ToASCII and ToUnicode operations available in
;; Emacs.

;; Example:
;;
;; (idna-to-ascii "räksmörgås.gnu.org")
;; => "xn--rksmrgs-5wao1o.gnu.org"
;;
;; (idna-to-ascii "www.gnu.org")
;; => "www.gnu.org"
;;
;; (idna-to-unicode "xn--rksmrgs-5wao1o.gnu.org")
;; => "räksmörgås.gnu.org"
;;
;; (idna-to-unicode "www.gnu.org")
;; => "www.gnu.org"

;; Todo: Support AllowUnassigned and UseSTD3ASCIIRules somehow?

;; This package is useless unless your emacs has at least partial
;; support for the UTF-8 coding system.

;; Report bugs to bug-libidn@gnu.org.

;;; Code:

(defgroup idna nil
  "Internationalizing Domain Names in Applications.")

(defcustom idna-program "idn"
  "Name of the GNU Libidn \"idn\" application."
  :type 'string
  :group 'idna)

(defcustom idna-environment '("CHARSET=UTF-8")
  "List of environment variable definitions prepended to `process-environment'."
  :type '(repeat string)
  :group 'idna)

(defcustom idna-to-ascii-parameters '("--quiet"
				      "--idna-to-ascii"
				      "--usestd3asciirules")
  "Parameters passed to `idna-program' to invoke IDNA ToASCII mode."
  :type '(repeat string)
  :group 'idna)

(defcustom idna-to-unicode-parameters '("--quiet"
					"--idna-to-unicode"
					"--usestd3asciirules")
  "Parameters passed `idna-program' to invoke IDNA ToUnicode mode."
  :type '(repeat string)
  :group 'idna)

;; Internal process handling:

(defvar idna-to-ascii-process nil
  "Internal variable holding process for ToASCII.")
(defvar idna-to-ascii-response nil
  "Internal variable holding response data received from ToASCII process.")

(defun idna-to-ascii-response-clear ()
  (setq idna-to-ascii-response nil))

(defun idna-to-ascii-response ()
  (while (and (eq (process-status idna-to-ascii-process) 'run)
	      (null idna-to-ascii-response))
    (accept-process-output idna-to-ascii-process 1))
  idna-to-ascii-response)

(defun idna-to-ascii-filter (process string)
  (setq idna-to-ascii-response (concat idna-to-ascii-response string)))

(defun idna-to-ascii-process ()
  (if (and idna-to-ascii-process
	   (eq (process-status idna-to-ascii-process) 'run))
      idna-to-ascii-process
    (if idna-to-ascii-process
	(condition-case ()
	    (kill-process idna-to-ascii-process)
	  (error)))
    (when (setq idna-to-ascii-process
		(let ((process-environment (append idna-environment
						   process-environment)))
		  (apply 'start-process "idna" nil idna-program
			 idna-to-ascii-parameters)))
      (set-process-filter idna-to-ascii-process 'idna-to-ascii-filter)
      (set-process-coding-system idna-to-ascii-process 'utf-8 'utf-8)
      (process-kill-without-query idna-to-ascii-process))
    idna-to-ascii-process))

(defvar idna-to-unicode-process nil
  "Internal variable holding process for ToASCII.")
(defvar idna-to-unicode-response nil
  "Internal variable holding response data received from ToASCII process.")

(defun idna-to-unicode-response-clear ()
  (setq idna-to-unicode-response nil))

(defun idna-to-unicode-response ()
  (while (and (eq (process-status idna-to-unicode-process) 'run)
	      (null idna-to-unicode-response))
    (accept-process-output idna-to-unicode-process 1))
  idna-to-unicode-response)

(defun idna-to-unicode-filter (process string)
  (setq idna-to-unicode-response (concat idna-to-unicode-response string)))

(defun idna-to-unicode-process ()
  (if (and idna-to-unicode-process
	   (eq (process-status idna-to-unicode-process) 'run))
      idna-to-unicode-process
    (if idna-to-unicode-process
	(condition-case ()
	    (kill-process idna-to-unicode-process)
	  (error)))
    (when (setq idna-to-unicode-process
		(let ((process-environment (append idna-environment
						   process-environment)))
		  (apply 'start-process "idna" nil idna-program
			 idna-to-unicode-parameters)))
      (set-process-filter idna-to-unicode-process 'idna-to-unicode-filter)
      (set-process-coding-system idna-to-unicode-process 'utf-8 'utf-8)
      (process-kill-without-query idna-to-unicode-process))
    idna-to-unicode-process))

;; IDNA Elisp API:

(defun idna-to-ascii (str)
  "Returns an ASCII Compatible Encoding (ACE) of STR.
It is computed by the IDNA ToASCII operation, after converting the
input to UTF-8."
  (let ((proc (idna-to-ascii-process))
	string)
    (if (null proc)
	(error "Cannot start idn application (to-ascii)")
      (idna-to-ascii-response-clear)
      (process-send-string proc (concat str "\n"))
      (setq string (idna-to-ascii-response))
      (if (and string (string= (substring string (1- (length string))) "\n"))
	  (substring string 0 (1- (length string)))
	string))))

(defun idna-to-unicode (str)
  "Returns a possibly multibyte string after decoding STR.
It is computed by the IDNA ToUnicode operation."
  (let ((proc (idna-to-unicode-process))
	string)
    (if (null proc)
	(error "Cannot start idn application (to-unicode)")
      (idna-to-unicode-response-clear)
      (process-send-string proc (concat str "\n"))
      (setq string (idna-to-unicode-response))
      (if (and string (string= (substring string (1- (length string))) "\n"))
	  (substring string 0 (1- (length string)))
	string))))

(defun idna-shutdown ()
  "Kill the IDNA related processes."
  (interactive)
  (if (and idna-to-ascii-process
	   (eq (process-status idna-to-ascii-process) 'run))
      (kill-process idna-to-ascii-process))
  (if (and idna-to-unicode-process
	   (eq (process-status idna-to-unicode-process) 'run))
      (kill-process idna-to-unicode-process)))

(provide 'idna)

;;; idna.el ends here
