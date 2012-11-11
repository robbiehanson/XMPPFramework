/* tst_toutf8.c --- Self tests for UTF-8 conversion functions.
 * Copyright (C) 2002-2012 Simon Josefsson
 *
 * This file is part of GNU Libidn.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>

#include <stringprep.h>

#include "utils.h"

void
doit (void)
{
  char *p;
  const char *q;

  q = stringprep_locale_charset ();
  if (q == NULL)
    fail ("FAIL: stringprep_locale_charset == NULL\n");
  if (debug)
    printf ("PASS: stringprep_locale_charset == %s\n", q);

  p = stringprep_locale_to_utf8 ("foo");
  if (!p || memcmp (p, "foo", 4) != 0)
    fail ("FAIL: stringprep_locale_to_utf8(\"foo\") == %s\n", p);
  if (debug)
    printf ("PASS: stringprep_locale_to_utf8(\"foo\") == %s\n", p);
  free (p);

  p = stringprep_utf8_to_locale ("foo");
  if (!p || memcmp (p, "foo", 4) != 0)
    fail ("FAIL: stringprep_utf8_to_locale(\"foo\") == %s\n", p);
  if (debug)
    printf ("PASS: stringprep_utf8_to_locale(\"foo\") == %s\n", p);
  free (p);
}
