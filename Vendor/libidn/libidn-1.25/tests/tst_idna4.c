/* tst_idna4.c --- Self tests for memory leak regression.
 * Copyright (C) 2011-2012 Simon Josefsson
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

#include <idna.h>
#include <idn-free.h>

#include "utils.h"

void
doit (void)
{
  int rc;
  char *out = NULL;

  rc = idna_to_ascii_8z("search...", &out, 0);
  if (rc != IDNA_INVALID_LENGTH)
    fail ("unexpected rc %d\n", rc);

  rc = idna_to_ascii_8z("google.com................point", &out, 0);
  if (rc != IDNA_INVALID_LENGTH)
    fail ("unexpected rc %d\n", rc);

  rc = idna_to_ascii_8z("Loading...같같같같같같같]", &out, 0);
  if (rc != IDNA_INVALID_LENGTH)
    fail ("unexpected rc %d\n", rc);
}
