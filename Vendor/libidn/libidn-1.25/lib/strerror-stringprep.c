/* strerror-stringprep.c --- Convert stringprep errors into text.
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

#include "stringprep.h"

#include "gettext.h"
#define _(String) dgettext (PACKAGE, String)

/**
 * stringprep_strerror:
 * @rc: a #Stringprep_rc return code.
 *
 * Convert a return code integer to a text string.  This string can be
 * used to output a diagnostic message to the user.
 *
 * STRINGPREP_OK: Successful operation.  This value is guaranteed to
 *   always be zero, the remaining ones are only guaranteed to hold
 *   non-zero values, for logical comparison purposes.
 * STRINGPREP_CONTAINS_UNASSIGNED: String contain unassigned Unicode
 *   code points, which is forbidden by the profile.
 * STRINGPREP_CONTAINS_PROHIBITED: String contain code points
 *   prohibited by the profile.
 * STRINGPREP_BIDI_BOTH_L_AND_RAL: String contain code points with
 *   conflicting bidirection category.
 * STRINGPREP_BIDI_LEADTRAIL_NOT_RAL: Leading and trailing character
 *   in string not of proper bidirectional category.
 * STRINGPREP_BIDI_CONTAINS_PROHIBITED: Contains prohibited code
 *   points detected by bidirectional code.
 * STRINGPREP_TOO_SMALL_BUFFER: Buffer handed to function was too
 *   small.  This usually indicate a problem in the calling
 *   application.
 * STRINGPREP_PROFILE_ERROR: The stringprep profile was inconsistent.
 *   This usually indicate an internal error in the library.
 * STRINGPREP_FLAG_ERROR: The supplied flag conflicted with profile.
 *   This usually indicate a problem in the calling application.
 * STRINGPREP_UNKNOWN_PROFILE: The supplied profile name was not
 *   known to the library.
 * STRINGPREP_NFKC_FAILED: The Unicode NFKC operation failed.  This
 *   usually indicate an internal error in the library.
 * STRINGPREP_MALLOC_ERROR: The malloc() was out of memory.  This is
 *   usually a fatal error.
 *
 * Return value: Returns a pointer to a statically allocated string
 *   containing a description of the error with the return code @rc.
 **/
const char *
stringprep_strerror (Stringprep_rc rc)
{
  const char *p;

  bindtextdomain (PACKAGE, LOCALEDIR);

  switch (rc)
    {
    case STRINGPREP_OK:
      p = _("Success");
      break;

    case STRINGPREP_CONTAINS_UNASSIGNED:
      p = _("Forbidden unassigned code points in input");
      break;

    case STRINGPREP_CONTAINS_PROHIBITED:
      p = _("Prohibited code points in input");
      break;

    case STRINGPREP_BIDI_BOTH_L_AND_RAL:
      p = _("Conflicting bidirectional properties in input");
      break;

    case STRINGPREP_BIDI_LEADTRAIL_NOT_RAL:
      p = _("Malformed bidirectional string");
      break;

    case STRINGPREP_BIDI_CONTAINS_PROHIBITED:
      p = _("Prohibited bidirectional code points in input");
      break;

    case STRINGPREP_TOO_SMALL_BUFFER:
      p = _("Output would exceed the buffer space provided");
      break;

    case STRINGPREP_PROFILE_ERROR:
      p = _("Error in stringprep profile definition");
      break;

    case STRINGPREP_FLAG_ERROR:
      p = _("Flag conflict with profile");
      break;

    case STRINGPREP_UNKNOWN_PROFILE:
      p = _("Unknown profile");
      break;

    case STRINGPREP_NFKC_FAILED:
      p = _("Unicode normalization failed (internal error)");
      break;

    case STRINGPREP_MALLOC_ERROR:
      p = _("Cannot allocate memory");
      break;

    default:
      p = _("Unknown error");
      break;
    }

  return p;
}
