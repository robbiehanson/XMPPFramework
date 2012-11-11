/* tst_idna3.c --- Self tests for upper-case XN-- regression.
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

struct idna
{
  const char *in;
  const char *out;
};

static const struct idna idna[] = {
  /* Test vectors from http://bugs.debian.org/610617 */
  { "XN----7SBAABF4DLDYSIEHP4NTB.XN--P1AI",
    "\xd1\x81\xd0\xb0\xd0\xbc\xd0\xb0\xd1\x80\xd1\x81\xd0\xba\xd0\xb0\xd1"
    "\x8f\x2d\xd0\xbe\xd0\xb1\xd0\xbb\xd0\xb0\xd1\x81\xd1\x82\xd1\x8c\x2e"
    "\xd1\x80\xd1\x84"},
  { "xn----7SBAABF4DLDYSIEHP4NTB.XN--P1AI",
    "\xd1\x81\xd0\xb0\xd0\xbc\xd0\xb0\xd1\x80\xd1\x81\xd0\xba\xd0\xb0\xd1"
    "\x8f\x2d\xd0\xbe\xd0\xb1\xd0\xbb\xd0\xb0\xd1\x81\xd1\x82\xd1\x8c\x2e"
    "\xd1\x80\xd1\x84"},
  { "xn----7SBAABF4DLDYSIEHP4NTB.xn--P1AI",
    "\xd1\x81\xd0\xb0\xd0\xbc\xd0\xb0\xd1\x80\xd1\x81\xd0\xba\xd0\xb0\xd1"
    "\x8f\x2d\xd0\xbe\xd0\xb1\xd0\xbb\xd0\xb0\xd1\x81\xd1\x82\xd1\x8c\x2e"
    "\xd1\x80\xd1\x84"}
};

void
doit (void)
{
  int rc;
  char *out = NULL;
  size_t i;

  for (i = 0; i < sizeof (idna) / sizeof (idna[0]); i++)
    {
      rc = idna_to_unicode_8z8z (idna[i].in, &out, 0);
      if (rc != IDNA_SUCCESS)
	fail ("IDNA3[%ld] failed %d\n", i, rc);

      if (debug && rc == IDNA_SUCCESS)
	{
	  printf ("input:        %s\n", idna[i].in);
	  printf ("computed out: %s\n", out);
	  printf ("expected out: %s\n", idna[i].out);
	}

      if (strcmp (out, idna[i].out) != 0)
	fail ("IDNA3[%ld] failed\n", i);
      else if (debug)
	printf ("IDNA3[%ld] success\n", i);

      if (out)
	idn_free (out);
    }
}
