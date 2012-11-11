/* tst_pr29.c --- Self tests for pr29_*().
 * Copyright (C) 2004-2012 Simon Josefsson
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

#include <pr29.h>

#include "utils.h"

struct tv
{
  const char *name;
  size_t inlen;
  uint32_t in[100];
  int rc;
};

static const struct tv tv[] = {
  {
   "Problem Sequence A",
   3,
   {0x1100, 0x0300, 0x1161, 0},
   PR29_PROBLEM},
  {
   "Test Case",
   3,
   {0x0B47, 0x0300, 0x0B3E, 0},
   PR29_PROBLEM},
  {
   "Instability Example",
   4,
   {0x1100, 0x0300, 0x1161, 0x0323, 0},
   PR29_PROBLEM},
  {
   "Not a problem sequence 1",
   3,
   {0x1100, 0x1161, 0x0300, 0},
   PR29_SUCCESS},
  {
   "Not a problem sequence 2",
   3,
   {0x0300, 0x1100, 0x1161, 0},
   PR29_SUCCESS},
  {
   "Not a problem sequence 3",
   3,
   {0x1161, 0x1100, 0x0300, 0},
   PR29_SUCCESS},
  {
   "Not a problem sequence 4",
   3,
   {0x1161, 0x0300, 0x1100, 0},
   PR29_SUCCESS},
  {
   "Not a problem sequence 5",
   3,
   {0x1100, 0x00AA, 0x1161, 0},
   PR29_SUCCESS},
  {
    /* http://lists.gnu.org/archive/html/help-libidn/2012-01/msg00008.html */
    "Infloop",
    3,
    {0x1100, 0x0300, 0x4711, 0},
    PR29_SUCCESS}
};

void
doit (void)
{
  size_t i;
  int rc;

  for (i = 0; i < sizeof (tv) / sizeof (tv[0]); i++)
    {
      if (debug)
	{
	  uint32_t *p, *q;

	  printf ("PR29 entry %ld: %s\n", i, tv[i].name);

	  printf ("in:\n");
	  ucs4print (tv[i].in, tv[i].inlen);

	  printf ("nfkc:\n");
	  p = stringprep_ucs4_nfkc_normalize (tv[i].in, tv[i].inlen);
	  ucs4print (p, -1);

	  printf ("second nfkc:\n");
	  q = stringprep_ucs4_nfkc_normalize (p, -1);
	  ucs4print (q, -1);

	  free (p);
	  free (q);
	}

      rc = pr29_4 (tv[i].in, tv[i].inlen);
      if (rc != tv[i].rc)
	{
	  fail ("PR29 entry %ld failed (expected %d): %d\n", i, tv[i].rc, rc);
	  if (debug)
	    printf ("FATAL\n");
	  continue;
	}

      rc = pr29_4z (tv[i].in);
      if (rc != tv[i].rc)
	{
	  fail ("PR29 entry %ld failed (expected %d): %d\n", i, tv[i].rc, rc);
	  if (debug)
	    printf ("FATAL\n");
	  continue;
	}

      {
	char *p;
	size_t items_read, items_written;

	p = stringprep_ucs4_to_utf8 (tv[i].in, (ssize_t) tv[i].inlen,
				     &items_read, &items_written);
	if (p == NULL)
	  fail ("FAIL: stringprep_ucs4_to_utf8(tv[%ld]) == NULL\n", i);
	if (debug)
	  hexprint (p, strlen (p));

	rc = pr29_8z (p);
	free (p);
	if (rc != tv[i].rc)
	  {
	    fail ("PR29 entry %ld failed (expected %d): %d\n",
		  i, tv[i].rc, rc);
	    if (debug)
	      printf ("FATAL\n");
	    continue;
	  }
      }

      if (debug)
	{
	  if (tv[i].rc != PR29_SUCCESS)
	    printf ("EXPECTED FAIL\n");
	  else
	    printf ("OK\n");
	}
    }
}
