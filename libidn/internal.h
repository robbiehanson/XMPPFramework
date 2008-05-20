/* internal.h	Internal header file for libidn.
 * Copyright (C) 2002, 2003  Simon Josefsson
 *
 * This file is part of GNU Libidn.
 *
 * GNU Libidn is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * GNU Libidn is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with GNU Libidn; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 */

#ifndef _INTERNAL_H
#define _INTERNAL_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <sys/types.h>

#define LOCALE_WORKS 1

#include "stringprep.h"

/*! \mainpage GNU Internationalized Domain Name Library
 *
 * \section intro Introduction
 *
 * GNU Libidn is an implementation of the Stringprep, Punycode and IDNA
 * specifications defined by the IETF Internationalized Domain Names
 * (IDN) working group, used for internationalized domain names.  The
 * package is available under the GNU Lesser General Public License.
 *
 * The library contains a generic Stringprep implementation that does
 * Unicode 3.2 NFKC normalization, mapping and prohibitation of
 * characters, and bidirectional character handling.  Profiles for iSCSI,
 * Kerberos 5, Nameprep, SASL and XMPP are included.  Punycode and ASCII
 * Compatible Encoding (ACE) via IDNA are supported.
 *
 * The Stringprep API consists of two main functions, one for converting
 * data from the system's native representation into UTF-8, and one
 * function to perform the Stringprep processing.  Adding a new
 * Stringprep profile for your application within the API is
 * straightforward.  The Punycode API consists of one encoding function
 * and one decoding function.  The IDNA API consists of the ToASCII and
 * ToUnicode functions, as well as an high-level interface for converting
 * entire domain names to and from the ACE encoded form.
 *
 * The library is used by, e.g., GNU SASL and Shishi to process user
 * names and passwords.  Libidn can be built into GNU Libc to enable a
 * new system-wide getaddrinfo() flag for IDN processing.
 *
 * Libidn is developed for the GNU/Linux system, but runs on over 20 Unix
 * platforms (including Solaris, IRIX, AIX, and Tru64) and Windows.
 * Libidn is written in C and (parts of) the API is accessible from C,
 * C++, Emacs Lisp, Python and Java.
 *
 * The project web page:\n
 * http://www.gnu.org/software/libidn/
 *
 * The software archive:\n
 * ftp://alpha.gnu.org/pub/gnu/libidn/
 *
 * For more information see:\n
 * http://www.ietf.org/html.charters/idn-charter.html\n
 * http://www.ietf.org/rfc/rfc3454.txt (stringprep specification)\n
 * http://www.ietf.org/rfc/rfc3490.txt (idna specification)\n
 * http://www.ietf.org/rfc/rfc3491.txt (nameprep specification)\n
 * http://www.ietf.org/rfc/rfc3492.txt (punycode specification)\n
 * http://www.ietf.org/internet-drafts/draft-ietf-ips-iscsi-string-prep-04.txt\n
 * http://www.ietf.org/internet-drafts/draft-ietf-krb-wg-utf8-profile-01.txt\n
 * http://www.ietf.org/internet-drafts/draft-ietf-sasl-anon-00.txt\n
 * http://www.ietf.org/internet-drafts/draft-ietf-sasl-saslprep-00.txt\n
 * http://www.ietf.org/internet-drafts/draft-ietf-xmpp-nodeprep-01.txt\n
 * http://www.ietf.org/internet-drafts/draft-ietf-xmpp-resourceprep-01.txt\n
 *
 * Further information and paid contract development:\n
 * Simon Josefsson <simon@josefsson.org>
 *
 * \section examples Examples
 *
 * \include example.c
 * \include example3.c
 * \include example4.c
 */

#endif /* _INTERNAL_H */
