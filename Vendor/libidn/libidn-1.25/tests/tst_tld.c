/* tst_tld.c --- Self tests for tld_*().
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

#include <stringprep.h>
#include <tld.h>

#include "utils.h"

struct tld
{
  const char *name;
  const char *tld;
  const char *example;
  size_t inlen;
  uint32_t in[100];
  int rc;
  size_t errpos;
};

static const struct tld tld[] = {
  {
   "Simple valid French domain",
   "fr",
   "example.fr",
   3,
   {0x00E0, 0x00E2, 0x00E6},
   TLD_SUCCESS},
  {
   "Simple invalid French domain",
   "fr",
   "ªexample.fr",
   5,
   {0x00E0, 0x00E2, 0x00E6, 0x4711, 0x0042},
   TLD_INVALID,
   3}
};

void
doit (void)
{
  size_t i;
  const Tld_table *tldtable;
  size_t errpos;
  int rc;

  tldtable = tld_get_table (NULL, NULL);
  if (tldtable != NULL)
    fail ("FAIL: tld_get_table (NULL, NULL) != NULL\n");

  tldtable = tld_get_table ("nonexisting", NULL);
  if (tldtable != NULL)
    fail ("FAIL: tld_get_table (\"nonexisting\", NULL) != NULL\n");

  tldtable = tld_default_table (NULL, NULL);
  if (tldtable != NULL)
    fail ("FAIL: tld_default_table (NULL, NULL) != NULL\n");

  for (i = 0; i < sizeof (tld) / sizeof (tld[0]); i++)
    {
      if (debug)
	printf ("TLD entry %ld: %s\n", i, tld[i].name);

      if (debug)
	{
	  printf ("in:\n");
	  ucs4print (tld[i].in, tld[i].inlen);
	}

      tldtable = tld_default_table (tld[i].tld, NULL);
      if (tldtable == NULL)
	{
	  fail ("TLD entry %ld tld_get_table (%s)\n", i, tld[i].tld);
	  if (debug)
	    printf ("FATAL\n");
	  continue;
	}

      rc = tld_check_4t (tld[i].in, tld[i].inlen, &errpos, tldtable);
      if (rc != tld[i].rc)
	{
	  fail ("TLD entry %ld failed: %d\n", i, rc);
	  if (debug)
	    printf ("FATAL\n");
	  continue;
	}

      if (debug)
	printf ("returned %d expected %d\n", rc, tld[i].rc);

      if (rc != tld[i].rc)
	{
	  fail ("TLD entry %ld failed\n", i);
	  if (debug)
	    printf ("ERROR\n");
	}
      else if (rc == TLD_INVALID)
	{
	  if (debug)
	    printf ("returned errpos %ld expected errpos %ld\n",
		    errpos, tld[i].errpos);

	  if (tld[i].errpos != errpos)
	    {
	      fail ("TLD entry %ld failed because errpos %ld != %ld\n", i,
		    tld[i].errpos, errpos);
	      if (debug)
		printf ("ERROR\n");
	    }
	}
      else if (debug)
	printf ("OK\n");

      {
	rc = tld_check_8z (tld[i].example, &errpos, NULL);
	if (rc != tld[i].rc)
	  {
	    fail ("TLD entry %ld failed\n", i);
	    if (debug)
	      printf ("ERROR\n");
	  }
	if (debug)
	  printf ("TLD entry %ld tld_check_8z (%s)\n", i, tld[i].example);
      }
    }
}
