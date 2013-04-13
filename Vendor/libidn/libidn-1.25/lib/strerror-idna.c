/* strerror-idna.c --- Convert IDNA errors into text.
   Copyright (C) 2004-2012 Simon Josefsson

   This file is part of GNU Libidn.

   GNU Libidn is free software: you can redistribute it and/or
   modify it under the terms of either:

     * the GNU Lesser General Public License as published by the Free
       Software Foundation; either version 3 of the License, or (at
       your option) any later version.

   or

     * the GNU General Public License as published by the Free
       Software Foundation; either version 2 of the License, or (at
       your option) any later version.

   or both in parallel, as here.

   GNU Libidn is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   General Public License for more details.

   You should have received copies of the GNU General Public License and
   the GNU Lesser General Public License along with this program.  If
   not, see <http://www.gnu.org/licenses/>. */

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "idna.h"

#include "gettext.h"
#define _(String) dgettext (PACKAGE, String)

/**
 * idna_strerror:
 * @rc: an #Idna_rc return code.
 *
 * Convert a return code integer to a text string.  This string can be
 * used to output a diagnostic message to the user.
 *
 * IDNA_SUCCESS: Successful operation.  This value is guaranteed to
 *   always be zero, the remaining ones are only guaranteed to hold
 *   non-zero values, for logical comparison purposes.
 * IDNA_STRINGPREP_ERROR:  Error during string preparation.
 * IDNA_PUNYCODE_ERROR: Error during punycode operation.
 * IDNA_CONTAINS_NON_LDH: For IDNA_USE_STD3_ASCII_RULES, indicate that
 *   the string contains non-LDH ASCII characters.
 * IDNA_CONTAINS_MINUS: For IDNA_USE_STD3_ASCII_RULES, indicate that
 *   the string contains a leading or trailing hyphen-minus (U+002D).
 * IDNA_INVALID_LENGTH: The final output string is not within the
 *   (inclusive) range 1 to 63 characters.
 * IDNA_NO_ACE_PREFIX: The string does not contain the ACE prefix
 *   (for ToUnicode).
 * IDNA_ROUNDTRIP_VERIFY_ERROR: The ToASCII operation on output
 *   string does not equal the input.
 * IDNA_CONTAINS_ACE_PREFIX: The input contains the ACE prefix (for
 *   ToASCII).
 * IDNA_ICONV_ERROR: Could not convert string in locale encoding.
 * IDNA_MALLOC_ERROR: Could not allocate buffer (this is typically a
 *   fatal error).
 * IDNA_DLOPEN_ERROR: Could not dlopen the libcidn DSO (only used
 *   internally in libc).
 *
 * Return value: Returns a pointer to a statically allocated string
 * containing a description of the error with the return code @rc.
 **/
const char *
idna_strerror (Idna_rc rc)
{
  const char *p;

  bindtextdomain (PACKAGE, LOCALEDIR);

  switch (rc)
    {
    case IDNA_SUCCESS:
      p = _("Success");
      break;

    case IDNA_STRINGPREP_ERROR:
      p = _("String preparation failed");
      break;

    case IDNA_PUNYCODE_ERROR:
      p = _("Punycode failed");
      break;

    case IDNA_CONTAINS_NON_LDH:
      p = _("Non-digit/letter/hyphen in input");
      break;

    case IDNA_CONTAINS_MINUS:
      p = _("Forbidden leading or trailing minus sign (`-')");
      break;

    case IDNA_INVALID_LENGTH:
      p = _("Output would be too large or too small");
      break;

    case IDNA_NO_ACE_PREFIX:
      p = _("Input does not start with ACE prefix (`xn--')");
      break;

    case IDNA_ROUNDTRIP_VERIFY_ERROR:
      p = _("String not idempotent under ToASCII");
      break;

    case IDNA_CONTAINS_ACE_PREFIX:
      p = _("Input already contain ACE prefix (`xn--')");
      break;

    case IDNA_ICONV_ERROR:
      p = _("System iconv failed");
      break;

    case IDNA_MALLOC_ERROR:
      p = _("Cannot allocate memory");
      break;

    case IDNA_DLOPEN_ERROR:
      p = _("System dlopen failed");
      break;

    default:
      p = _("Unknown error");
      break;
    }

  return p;
}
