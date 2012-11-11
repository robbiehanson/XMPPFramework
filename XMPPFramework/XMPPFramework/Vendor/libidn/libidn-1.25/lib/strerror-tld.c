/* strerror-tld.c --- Convert TLD errors into text.
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

#include "tld.h"

#include "gettext.h"
#define _(String) dgettext (PACKAGE, String)

/**
 * tld_strerror:
 * @rc: tld return code
 *
 * Convert a return code integer to a text string.  This string can be
 * used to output a diagnostic message to the user.
 *
 * TLD_SUCCESS: Successful operation.  This value is guaranteed to
 *   always be zero, the remaining ones are only guaranteed to hold
 *   non-zero values, for logical comparison purposes.
 * TLD_INVALID: Invalid character found.
 * TLD_NODATA: No input data was provided.
 * TLD_MALLOC_ERROR: Error during memory allocation.
 * TLD_ICONV_ERROR: Error during iconv string conversion.
 * TLD_NO_TLD: No top-level domain found in domain string.
 *
 * Return value: Returns a pointer to a statically allocated string
 * containing a description of the error with the return code @rc.
 **/
const char *
tld_strerror (Tld_rc rc)
{
  const char *p;

  bindtextdomain (PACKAGE, LOCALEDIR);

  switch (rc)
    {
    case TLD_SUCCESS:
      p = _("Success");
      break;

    case TLD_INVALID:
      p = _("Code points prohibited by top-level domain");
      break;

    case TLD_NODATA:
      p = _("Missing input");
      break;

    case TLD_MALLOC_ERROR:
      p = _("Cannot allocate memory");
      break;

    case TLD_ICONV_ERROR:
      p = _("System iconv failed");
      break;

    case TLD_NO_TLD:
      p = _("No top-level domain found in input");
      break;

    default:
      p = _("Unknown error");
      break;
    }

  return p;
}
