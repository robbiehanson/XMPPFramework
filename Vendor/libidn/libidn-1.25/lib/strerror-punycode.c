/* strerror-punycode.c --- Convert punycode errors into text.
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

#include "punycode.h"

#include "gettext.h"
#define _(String) dgettext (PACKAGE, String)

/**
 * punycode_strerror:
 * @rc: an #Punycode_status return code.
 *
 * Convert a return code integer to a text string.  This string can be
 * used to output a diagnostic message to the user.
 *
 * PUNYCODE_SUCCESS: Successful operation.  This value is guaranteed
 *   to always be zero, the remaining ones are only guaranteed to hold
 *   non-zero values, for logical comparison purposes.
 * PUNYCODE_BAD_INPUT: Input is invalid.
 * PUNYCODE_BIG_OUTPUT: Output would exceed the space provided.
 * PUNYCODE_OVERFLOW: Input needs wider integers to process.
 *
 * Return value: Returns a pointer to a statically allocated string
 * containing a description of the error with the return code @rc.
 **/
const char *
punycode_strerror (Punycode_status rc)
{
  const char *p;

  bindtextdomain (PACKAGE, LOCALEDIR);

  switch (rc)
    {
    case PUNYCODE_SUCCESS:
      p = _("Success");
      break;

    case PUNYCODE_BAD_INPUT:
      p = _("Invalid input");
      break;

    case PUNYCODE_BIG_OUTPUT:
      p = _("Output would exceed the buffer space provided");
      break;

    case PUNYCODE_OVERFLOW:
      p = _("String size limit exceeded");
      break;

    default:
      p = _("Unknown error");
      break;
    }

  return p;
}
