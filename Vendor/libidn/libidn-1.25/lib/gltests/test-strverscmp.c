/* Test of strverscmp() function.
   Copyright (C) 2008-2012 Free Software Foundation, Inc.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3, or (at your option)
   any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, see <http://www.gnu.org/licenses/>.  */

/* Written by Eric Blake <ebb9@byu.net>, 2008.  */

#include <config.h>

#include <string.h>

#include "signature.h"
SIGNATURE_CHECK (strverscmp, int, (const char *, const char *));

#include "macros.h"

int
main (void)
{
  ASSERT (strverscmp ("", "") == 0);
  ASSERT (strverscmp ("a", "a") == 0);
  ASSERT (strverscmp ("a", "b") < 0);
  ASSERT (strverscmp ("b", "a") > 0);
  ASSERT (strverscmp ("000", "00") < 0);
  ASSERT (strverscmp ("00", "000") > 0);
  ASSERT (strverscmp ("a0", "a") > 0);
  ASSERT (strverscmp ("00", "01") < 0);
  ASSERT (strverscmp ("01", "010") < 0);
  ASSERT (strverscmp ("010", "09") < 0);
  ASSERT (strverscmp ("09", "0") < 0);
  ASSERT (strverscmp ("9", "10") < 0);
  ASSERT (strverscmp ("0a", "0") > 0);
  return 0;
}
