/* tst_nfkc.c --- Self tests for stringprep_utf8_nfkc_normalize().
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

struct nfkc
{
  const char *in;
  const char *out;
};

static struct nfkc nfkc[] = {
  {"\xC2\xB5", "\xCE\xBC"},
  {"\xC2\xAA", "\x61"},
  /* From <http://www.unicode.org/review/pr-29.html>. Note that we
   * compute the output according to Unicode 3.2 without the proposed
   * update.
   *
   *   1.
   *
   *   U+1100 (ᄀ) HANGUL CHOSEONG KIYEOK +
   *   U+0300 (◌̀) COMBINING GRAVE ACCENT +
   *   U+1161 (ᅡ) HANGUL JUNGSEONG A
   *
   *   According to the old language, the NFC form of this would be B:
   *
   *   2.
   *
   *   U+AC00 (가) HANGUL SYLLABLE GA +
   *   U+0300 (◌̀) COMBINING GRAVE ACCENT
   */
  {"\xE1\x84\x80\xCC\x80\xE1\x85\xA1", "\xEA\xB0\x80\xCC\x80"},
  /* Second test case from page.  Again, we do not implement the
   * updated proposal.  <U+0B47; U+0300; U+0B3E> -> U+0B4B U+0300
   */
  {"\xE0\xAD\x87\xCC\x80\xE0\xAC\xBE", "\xE0\xAD\x8b\xCC\x80"}
};

void
doit (void)
{
  char *out;
  size_t i;

  for (i = 0; i < sizeof (nfkc) / sizeof (nfkc[0]); i++)
    {
      if (debug)
	printf ("NFKC entry %ld\n", i);

      out = stringprep_utf8_nfkc_normalize (nfkc[i].in,
					    (ssize_t) strlen (nfkc[i].in));
      if (out == NULL)
	{
	  fail ("NFKC entry %ld failed fatally\n", i);
	  continue;
	}

      if (debug)
	{
	  uint32_t *t;
	  size_t len;

	  printf ("in:\n");
	  escapeprint (nfkc[i].in, strlen (nfkc[i].in));
	  hexprint (nfkc[i].in, strlen (nfkc[i].in));
	  binprint (nfkc[i].in, strlen (nfkc[i].in));


	  printf ("out:\n");
	  escapeprint (out, strlen (out));
	  hexprint (out, strlen (out));
	  binprint (out, strlen (out));
	  t = stringprep_utf8_to_ucs4 (out, -1, &len);
	  if (t)
	    {
	      ucs4print (t, len);
	      free (t);
	    }

	  printf ("expected out:\n");
	  escapeprint (nfkc[i].out, strlen (nfkc[i].out));
	  hexprint (nfkc[i].out, strlen (nfkc[i].out));
	  binprint (nfkc[i].out, strlen (nfkc[i].out));
	}

      if (strlen (nfkc[i].out) != strlen (out) ||
	  memcmp (nfkc[i].out, out, strlen (out)) != 0)
	{
	  fail ("NFKC entry %ld failed\n", i);
	  if (debug)
	    printf ("ERROR\n");
	}
      else if (debug)
	printf ("OK\n");

      free (out);
    }
}
