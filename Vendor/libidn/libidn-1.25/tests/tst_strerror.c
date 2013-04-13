/* tst_strerror.c --- Self tests for *_strerror().
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

#include <idna.h>
#include <pr29.h>
#include <punycode.h>
#include <stringprep.h>
#include <tld.h>

#include "utils.h"

#define SUCCESS "Success"
#define UNKNOWN "Unknown error"

void
doit (void)
{
  const char *p;

  /* Test success. */

  p = idna_strerror (0);
  if (strcmp (p, SUCCESS) != 0)
    fail ("idna_strerror (0) failed: %s\n", p);
  if (debug)
    printf ("idna_strerror (0) OK\n");

  p = pr29_strerror (0);
  if (strcmp (p, SUCCESS) != 0)
    fail ("pr29_strerror (0) failed: %s\n", p);
  if (debug)
    printf ("pr29_strerror (0) OK\n");

  p = punycode_strerror (0);
  if (strcmp (p, SUCCESS) != 0)
    fail ("punycode_strerror (0) failed: %s\n", p);
  if (debug)
    printf ("punycode_strerror (0) OK\n");

  p = stringprep_strerror (0);
  if (strcmp (p, SUCCESS) != 0)
    fail ("stringprep_strerror (0) failed: %s\n", p);
  if (debug)
    printf ("stringprep_strerror (0) OK\n");

  p = tld_strerror (0);
  if (strcmp (p, SUCCESS) != 0)
    fail ("tld_strerror (0) failed: %s\n", p);
  if (debug)
    printf ("tld_strerror (0) OK\n");

  /* Test unknown error. */

  p = idna_strerror (42);
  if (strcmp (p, UNKNOWN) != 0)
    fail ("idna_strerror (42) failed: %s\n", p);
  if (debug)
    printf ("idna_strerror (42) OK\n");

  p = pr29_strerror (42);
  if (strcmp (p, UNKNOWN) != 0)
    fail ("pr29_strerror (42) failed: %s\n", p);
  if (debug)
    printf ("pr29_strerror (42) OK\n");

  p = punycode_strerror (42);
  if (strcmp (p, UNKNOWN) != 0)
    fail ("punycode_strerror (42) failed: %s\n", p);
  if (debug)
    printf ("punycode_strerror (42) OK\n");

  p = stringprep_strerror (42);
  if (strcmp (p, UNKNOWN) != 0)
    fail ("stringprep_strerror (42) failed: %s\n", p);
  if (debug)
    printf ("stringprep_strerror (42) OK\n");

  p = tld_strerror (42);
  if (strcmp (p, UNKNOWN) != 0)
    fail ("tld_strerror (42) failed: %s\n", p);
  if (debug)
    printf ("tld_strerror (42) OK\n");

  /* Iterate through all error codes. */

  {
    size_t i;
    const char *last_p = NULL;

    for (i = 0;; i++)
      {
	p = idna_strerror (i);
	if (p == last_p)
	  {
	    if (i == 11)
	      {
		i = 200;
		continue;
	      }
	    break;
	  }
	if (debug)
	  printf ("idna %ld: %s\n", i, p);
	last_p = p;
      }
  }

  {
    size_t i;
    const char *last_p = NULL;

    for (i = 0;; i++)
      {
	p = pr29_strerror (i);
	if (p == last_p)
	  break;
	if (debug)
	  printf ("pr29 %ld: %s\n", i, p);
	last_p = p;
      }
  }

  {
    size_t i;
    const char *last_p = NULL;

    for (i = 0;; i++)
      {
	p = punycode_strerror (i);
	if (p == last_p)
	  break;
	if (debug)
	  printf ("punycode %ld: %s\n", i, p);
	last_p = p;
      }
  }

  {
    size_t i;
    const char *last_p = NULL;

    for (i = 0;; i++)
      {
	p = stringprep_strerror (i);
	if (p == last_p)
	  {
	    if (i == 7)
	      {
		i = 99;
		continue;
	      }
	    else if (i == 105)
	      {
		i = 199;
		continue;
	      }
	    break;
	  }
	if (debug)
	  printf ("stringprep %ld: %s\n", i, p);
	last_p = p;
      }
  }

  {
    size_t i;
    const char *last_p = NULL;

    for (i = 0;; i++)
      {
	p = tld_strerror (i);
	if (p == last_p)
	  break;
	if (debug)
	  printf ("tld %ld: %s\n", i, p);
	last_p = p;
      }
  }
}
