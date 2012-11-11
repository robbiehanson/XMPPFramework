/* tst_stringprep.c --- Self tests for stringprep().
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

struct stringprep
{
  const char *comment;
  const char *in;
  const char *out;
  const char *profile;
  int flags;
  int rc;
};

const struct stringprep strprep[] = {
  {"Map to nothing",
   "foo\xC2\xAD\xCD\x8F\xE1\xA0\x86\xE1\xA0\x8B"
   "bar" "\xE2\x80\x8B\xE2\x81\xA0" "baz\xEF\xB8\x80\xEF\xB8\x88"
   "\xEF\xB8\x8F\xEF\xBB\xBF", "foobarbaz"},
  {"Case folding ASCII U+0043 U+0041 U+0046 U+0045", "CAFE", "cafe"},
  {"Case folding 8bit U+00DF (german sharp s)", "\xC3\x9F", "ss"},
  {"Case folding U+0130 (turkish capital I with dot)",
   "\xC4\xB0", "i\xcc\x87"},
  {"Case folding multibyte U+0143 U+037A",
   "\xC5\x83\xCD\xBA", "\xC5\x84 \xCE\xB9"},
  {"Case folding U+2121 U+33C6 U+1D7BB",
   "\xE2\x84\xA1\xE3\x8F\x86\xF0\x9D\x9E\xBB",
   "telc\xE2\x88\x95" "kg\xCF\x83"},
  {"Normalization of U+006a U+030c U+00A0 U+00AA",
   "\x6A\xCC\x8C\xC2\xA0\xC2\xAA", "\xC7\xB0 a"},
  {"Case folding U+1FB7 and normalization",
   "\xE1\xBE\xB7", "\xE1\xBE\xB6\xCE\xB9"},
  {"Self-reverting case folding U+01F0 and normalization",
   "\xC7\xB0", "\xC7\xB0"},
  {"Self-reverting case folding U+0390 and normalization",
   "\xCE\x90", "\xCE\x90"},
  {"Self-reverting case folding U+03B0 and normalization",
   "\xCE\xB0", "\xCE\xB0"},
  {"Self-reverting case folding U+1E96 and normalization",
   "\xE1\xBA\x96", "\xE1\xBA\x96"},
  {"Self-reverting case folding U+1F56 and normalization",
   "\xE1\xBD\x96", "\xE1\xBD\x96"},
  {"ASCII space character U+0020", "\x20", "\x20"},
  {"Non-ASCII 8bit space character U+00A0", "\xC2\xA0", "\x20"},
  {"Non-ASCII multibyte space character U+1680",
   "\xE1\x9A\x80", NULL, "Nameprep", 0, STRINGPREP_CONTAINS_PROHIBITED},
  {"Non-ASCII multibyte space character U+2000", "\xE2\x80\x80", "\x20"},
  {"Zero Width Space U+200b", "\xE2\x80\x8b", ""},
  {"Non-ASCII multibyte space character U+3000", "\xE3\x80\x80", "\x20"},
  {"ASCII control characters U+0010 U+007F", "\x10\x7F", "\x10\x7F"},
  {"Non-ASCII 8bit control character U+0085",
   "\xC2\x85", NULL, "Nameprep", 0, STRINGPREP_CONTAINS_PROHIBITED},
  {"Non-ASCII multibyte control character U+180E",
   "\xE1\xA0\x8E", NULL, "Nameprep", 0, STRINGPREP_CONTAINS_PROHIBITED},
  {"Zero Width No-Break Space U+FEFF", "\xEF\xBB\xBF", ""},
  {"Non-ASCII control character U+1D175",
   "\xF0\x9D\x85\xB5", NULL, "Nameprep", 0,
   STRINGPREP_CONTAINS_PROHIBITED},
  {"Plane 0 private use character U+F123",
   "\xEF\x84\xA3", NULL, "Nameprep", 0, STRINGPREP_CONTAINS_PROHIBITED},
  {"Plane 15 private use character U+F1234",
   "\xF3\xB1\x88\xB4", NULL, "Nameprep", 0,
   STRINGPREP_CONTAINS_PROHIBITED},
  {"Plane 16 private use character U+10F234",
   "\xF4\x8F\x88\xB4", NULL, "Nameprep", 0,
   STRINGPREP_CONTAINS_PROHIBITED},
  {"Non-character code point U+8FFFE",
   "\xF2\x8F\xBF\xBE", NULL, "Nameprep", 0,
   STRINGPREP_CONTAINS_PROHIBITED},
  {"Non-character code point U+10FFFF",
   "\xF4\x8F\xBF\xBF", NULL, "Nameprep", 0,
   STRINGPREP_CONTAINS_PROHIBITED},
  {"Surrogate code U+DF42",
   "\xED\xBD\x82", NULL, "Nameprep", 0, STRINGPREP_CONTAINS_PROHIBITED},
  {"Non-plain text character U+FFFD",
   "\xEF\xBF\xBD", NULL, "Nameprep", 0, STRINGPREP_CONTAINS_PROHIBITED},
  {"Ideographic description character U+2FF5",
   "\xE2\xBF\xB5", NULL, "Nameprep", 0, STRINGPREP_CONTAINS_PROHIBITED},
  {"Display property character U+0341", "\xCD\x81", "\xCC\x81"},
  {"Left-to-right mark U+200E",
   "\xE2\x80\x8E", "\xCC\x81", "Nameprep", 0,
   STRINGPREP_CONTAINS_PROHIBITED},
  {"Deprecated U+202A", "\xE2\x80\xAA", "\xCC\x81", "Nameprep", 0,
   STRINGPREP_CONTAINS_PROHIBITED},
  {"Language tagging character U+E0001",
   "\xF3\xA0\x80\x81", "\xCC\x81", "Nameprep", 0,
   STRINGPREP_CONTAINS_PROHIBITED},
  {"Language tagging character U+E0042",
   "\xF3\xA0\x81\x82", NULL, "Nameprep", 0,
   STRINGPREP_CONTAINS_PROHIBITED},
  {"Bidi: RandALCat character U+05BE and LCat characters",
   "foo\xD6\xBE" "bar", NULL, "Nameprep", 0,
   STRINGPREP_BIDI_BOTH_L_AND_RAL},
  {"Bidi: RandALCat character U+FD50 and LCat characters",
   "foo\xEF\xB5\x90" "bar", NULL, "Nameprep", 0,
   STRINGPREP_BIDI_BOTH_L_AND_RAL},
  {"Bidi: RandALCat character U+FB38 and LCat characters",
   "foo\xEF\xB9\xB6" "bar", "foo \xd9\x8e" "bar"},
  {"Bidi: RandALCat without trailing RandALCat U+0627 U+0031",
   "\xD8\xA7\x31", NULL, "Nameprep", 0, STRINGPREP_BIDI_LEADTRAIL_NOT_RAL},
  {"Bidi: RandALCat character U+0627 U+0031 U+0628",
   "\xD8\xA7\x31\xD8\xA8", "\xD8\xA7\x31\xD8\xA8"},
  {"Unassigned code point U+E0002",
   "\xF3\xA0\x80\x82", NULL, "Nameprep", STRINGPREP_NO_UNASSIGNED,
   STRINGPREP_CONTAINS_UNASSIGNED},
  {"Larger test (shrinking)",
   "X\xC2\xAD\xC3\x9F\xC4\xB0\xE2\x84\xA1\x6a\xcc\x8c\xc2\xa0\xc2"
   "\xaa\xce\xb0\xe2\x80\x80", "xssi\xcc\x87" "tel\xc7\xb0 a\xce\xb0 ",
   "Nameprep"},
  {"Larger test (expanding)",
   "X\xC3\x9F\xe3\x8c\x96\xC4\xB0\xE2\x84\xA1\xE2\x92\x9F\xE3\x8c\x80",
   "xss\xe3\x82\xad\xe3\x83\xad\xe3\x83\xa1\xe3\x83\xbc\xe3\x83\x88"
   "\xe3\x83\xab" "i\xcc\x87" "tel\x28" "d\x29\xe3\x82\xa2\xe3\x83\x91"
   "\xe3\x83\xbc\xe3\x83\x88"},
  {"Test of prohibited ASCII character U+0020",
   "\x20", NULL, "Nodeprep", 0, STRINGPREP_CONTAINS_PROHIBITED},
  {"Test of NFKC U+00A0 and prohibited character U+0020",
   "\xC2\xA0", NULL, "Nodeprep", 0, STRINGPREP_CONTAINS_PROHIBITED},
  {"Case map + normalization", "\xC2\xB5", "\xCE\xBC", "Nameprep"},
  /* The rest are rather non-interesting, but no point in removing
     working test cases... */
  {"case_nonfkc", "\xC2\xB5", "\xCE\xBC", "Nameprep", STRINGPREP_NO_NFKC,
   STRINGPREP_FLAG_ERROR},
  {"NFKC test", "\xC2\xAA", "\x61", "Nameprep"},
  {"nameprep, exposed a bug in libstringprep 0.0.5",
   "\xC2\xAA\x0A", "\x61\x0A"},
  {"unassigned code point U+0221", "\xC8\xA1", "\xC8\xA1", "Nameprep"},
  {"Unassigned code point U+0221",
   "\xC8\xA1", NULL, "Nameprep", STRINGPREP_NO_UNASSIGNED,
   STRINGPREP_CONTAINS_UNASSIGNED},
  {"Unassigned code point U+0236", "\xC8\xB6", "\xC8\xB6", "Nameprep"},
  {"unassigned code point U+0236",
   "\xC8\xB6", NULL, "Nameprep", STRINGPREP_NO_UNASSIGNED,
   STRINGPREP_CONTAINS_UNASSIGNED},
  {"bidi both RandALCat and LCat  U+0627 U+00AA U+0628",
   "\xD8\xA7\xC2\xAA\xD8\xA8", NULL, "Nameprep", 0,
   STRINGPREP_BIDI_BOTH_L_AND_RAL},
  /* XMPP */
  {"XMPP node profile prohibited output",
   "foo@bar", NULL, "Nodeprep", 0, STRINGPREP_CONTAINS_PROHIBITED},
  {"XMPP resource profile on same string should work though",
   "foo@bar", "foo@bar", "Resourceprep"},
  /* iSCSI */
  {"iSCSI 1", "Example-Name", "example-name", "iSCSI"},
  {"iSCSI 2", "O+o", NULL, "iSCSI", 0, STRINGPREP_CONTAINS_PROHIBITED},
  {"iSCSI 3", "\x01", NULL, "iSCSI", 0, STRINGPREP_CONTAINS_PROHIBITED},
  {"iSCSI 4", "\xE3\x80\x82", NULL, "iSCSI", 0,
   STRINGPREP_CONTAINS_PROHIBITED},
  {"iSCSI 5", "\xE2\xBF\xB5", NULL, "iSCSI", 0,
   STRINGPREP_CONTAINS_PROHIBITED},
  {"SASL profile", "Example\xC2\xA0" "Name", "Example Name", "SASLprep"},
  /* SASL trace */
  {"SASL ANONYMOUS plain mechanism", "simon@josefsson.org",
   "simon@josefsson.org", "plain"},
  {"SASLprep 1 old", "x\xC2\xADy", "xy", "SASLprep"},
  {"SASLprep 4 old", "\xE2\x85\xA3", "IV", "SASLprep"},
  /* SASLprep test vectors. */
  {"SASLprep 1 SOFT HYPHEN mapped to nothing", "I\xC2\xADX", "IX",
   "SASLprep"},
  {"SASLprep 2 no transformation", "user", "user", "SASLprep"},
  {"SASLprep 3 case preserved, will not match #2", "USER", "USER",
   "SASLprep"},
  {"SASLprep 4 output is NFKC, input in ISO 8859-1", "\xC2\xAA", "a",
   "SASLprep"},
  {"SASLprep 5 output is NFKC, will match #1", "\xE2\x85\xA8", "IX",
   "SASLprep"},
  {"SASLprep 6 Error - prohibited character", "\x07", NULL, "SASLprep",
   0, STRINGPREP_CONTAINS_PROHIBITED},
  {"SASLprep 7 Error - bidirectional check", "\xD8\xA7" "1", NULL, "SASLprep",
   0, STRINGPREP_BIDI_LEADTRAIL_NOT_RAL}
};

void
doit (void)
{
  char *p;
  int rc;
  size_t i;

  if (!stringprep_check_version (STRINGPREP_VERSION))
    fail ("stringprep_check_version(%s) failed\n", STRINGPREP_VERSION);

  if (!stringprep_check_version (NULL))
    fail ("stringprep_check_version(NULL) failed\n");

  if (stringprep_check_version ("100.100"))
    fail ("stringprep_check_version(\"100.100\") failed\n");

  for (i = 0; i < sizeof (strprep) / sizeof (strprep[0]); i++)
    {
      if (debug)
	printf ("STRINGPREP entry %ld\n", i);

      if (debug)
	{
	  printf ("flags: %d\n", strprep[i].flags);

	  printf ("in: ");
	  escapeprint (strprep[i].in, strlen (strprep[i].in));
	  hexprint (strprep[i].in, strlen (strprep[i].in));
	  binprint (strprep[i].in, strlen (strprep[i].in));
	}

      {
	uint32_t *l;
	char *x;
	l = stringprep_utf8_to_ucs4 (strprep[i].in, -1, NULL);
	x = stringprep_ucs4_to_utf8 (l, -1, NULL, NULL);
	free (l);

	if (strcmp (strprep[i].in, x) != 0)
	  {
	    fail ("bad UTF-8 in entry %ld\n", i);
	    if (debug)
	      {
		puts ("expected:");
		escapeprint (strprep[i].in, strlen (strprep[i].in));
		hexprint (strprep[i].in, strlen (strprep[i].in));
		puts ("computed:");
		escapeprint (x, strlen (x));
		hexprint (x, strlen (x));
	      }
	  }

	free (x);
      }
      rc = stringprep_profile (strprep[i].in, &p,
			       strprep[i].profile ?
			       strprep[i].profile :
			       "Nameprep", strprep[i].flags);
      if (rc != strprep[i].rc)
	{
	  fail ("stringprep() entry %ld failed: %d\n", i, rc);
	  if (debug)
	    printf ("FATAL\n");
	  if (rc == STRINGPREP_OK)
	    free (p);
	  continue;
	}

      if (debug && rc == STRINGPREP_OK)
	{
	  printf ("out: ");
	  escapeprint (p, strlen (p));
	  hexprint (p, strlen (p));
	  binprint (p, strlen (p));

	  printf ("expected out: ");
	  escapeprint (strprep[i].out, strlen (strprep[i].out));
	  hexprint (strprep[i].out, strlen (strprep[i].out));
	  binprint (strprep[i].out, strlen (strprep[i].out));
	}
      else if (debug)
	printf ("returned %d expected %d\n", rc, strprep[i].rc);

      if (rc == STRINGPREP_OK)
	{
	  if (strlen (strprep[i].out) != strlen (p) ||
	      memcmp (strprep[i].out, p, strlen (p)) != 0)
	    {
	      fail ("stringprep() entry %ld failed\n", i);
	      if (debug)
		printf ("ERROR\n");
	    }
	  else if (debug)
	    printf ("OK\n\n");

	  free (p);
	}
      else if (debug)
	printf ("OK\n\n");
    }

#if 0
  {
    char p[20];
    memset (p, 0, 10);
    stringprep_unichar_to_utf8 (0x00DF, p);
    hexprint (p, strlen (p));
    puts ("");
  }
#endif
}
