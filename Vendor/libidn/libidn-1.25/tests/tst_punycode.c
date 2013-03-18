/* tst_punycode.c --- Self tests for punycode.
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

#include <punycode.h>

#include "utils.h"

struct punycode
{
  const char *name;
  size_t inlen;
  uint32_t in[100];
  const char *out;
  int rc;
};

const struct punycode punycode[] = {
  {
   "(A) Arabic (Egyptian)", 17,
   {
    0x0644, 0x064A, 0x0647, 0x0645, 0x0627, 0x0628, 0x062A, 0x0643,
    0x0644, 0x0645, 0x0648, 0x0634, 0x0639, 0x0631, 0x0628, 0x064A,
    0x061F}, "egbpdaj6bu4bxfgehfvwxn", PUNYCODE_SUCCESS},
  {
   "(B) Chinese (simplified)", 9,
   {
    0x4ED6, 0x4EEC, 0x4E3A, 0x4EC0, 0x4E48, 0x4E0D, 0x8BF4, 0x4E2D,
    0x6587}, "ihqwcrb4cv8a8dqg056pqjye", PUNYCODE_SUCCESS},
  {
   "(C) Chinese (traditional)", 9,
   {
    0x4ED6, 0x5011, 0x7232, 0x4EC0, 0x9EBD, 0x4E0D, 0x8AAA, 0x4E2D,
    0x6587}, "ihqwctvzc91f659drss3x8bo0yb", PUNYCODE_SUCCESS},
  {
   "(D) Czech: Pro<ccaron>prost<ecaron>nemluv<iacute><ccaron>esky", 22,
   {
    0x0050, 0x0072, 0x006F, 0x010D, 0x0070, 0x0072, 0x006F, 0x0073,
    0x0074, 0x011B, 0x006E, 0x0065, 0x006D, 0x006C, 0x0075, 0x0076,
    0x00ED, 0x010D, 0x0065, 0x0073, 0x006B, 0x0079},
   "Proprostnemluvesky-uyb24dma41a", PUNYCODE_SUCCESS},
  {
   "(E) Hebrew:", 22,
   {
    0x05DC, 0x05DE, 0x05D4, 0x05D4, 0x05DD, 0x05E4, 0x05E9, 0x05D5,
    0x05D8, 0x05DC, 0x05D0, 0x05DE, 0x05D3, 0x05D1, 0x05E8, 0x05D9,
    0x05DD, 0x05E2, 0x05D1, 0x05E8, 0x05D9, 0x05EA},
   "4dbcagdahymbxekheh6e0a7fei0b", PUNYCODE_SUCCESS},
  {
   "(F) Hindi (Devanagari):", 30,
   {
    0x092F, 0x0939, 0x0932, 0x094B, 0x0917, 0x0939, 0x093F, 0x0928,
    0x094D, 0x0926, 0x0940, 0x0915, 0x094D, 0x092F, 0x094B, 0x0902,
    0x0928, 0x0939, 0x0940, 0x0902, 0x092C, 0x094B, 0x0932, 0x0938,
    0x0915, 0x0924, 0x0947, 0x0939, 0x0948, 0x0902},
   "i1baa7eci9glrd9b2ae1bj0hfcgg6iyaf8o0a1dig0cd", PUNYCODE_SUCCESS},
  {
   "(G) Japanese (kanji and hiragana):", 18,
   {
    0x306A, 0x305C, 0x307F, 0x3093, 0x306A, 0x65E5, 0x672C, 0x8A9E,
    0x3092, 0x8A71, 0x3057, 0x3066, 0x304F, 0x308C, 0x306A, 0x3044,
    0x306E, 0x304B},
   "n8jok5ay5dzabd5bym9f0cm5685rrjetr6pdxa", PUNYCODE_SUCCESS},
  {
   "(H) Korean (Hangul syllables):", 24,
   {
    0xC138, 0xACC4, 0xC758, 0xBAA8, 0xB4E0, 0xC0AC, 0xB78C, 0xB4E4,
    0xC774, 0xD55C, 0xAD6D, 0xC5B4, 0xB97C, 0xC774, 0xD574, 0xD55C,
    0xB2E4, 0xBA74, 0xC5BC, 0xB9C8, 0xB098, 0xC88B, 0xC744, 0xAE4C},
   "989aomsvi5e83db1d2a355cv1e0vak1dwrv93d5xbh15a0dt30a5jpsd879ccm6fea98c",
   PUNYCODE_SUCCESS},
  {
   "(I) Russian (Cyrillic):", 28,
   {
    0x043F, 0x043E, 0x0447, 0x0435, 0x043C, 0x0443, 0x0436, 0x0435,
    0x043E, 0x043D, 0x0438, 0x043D, 0x0435, 0x0433, 0x043E, 0x0432,
    0x043E, 0x0440, 0x044F, 0x0442, 0x043F, 0x043E, 0x0440, 0x0443,
    0x0441, 0x0441, 0x043A, 0x0438},
   "b1abfaaepdrnnbgefbadotcwatmq2g4l", PUNYCODE_SUCCESS},
  {
   "(J) Spanish: Porqu<eacute>nopuedensimplementehablarenEspa<ntilde>ol", 40,
   {
    0x0050, 0x006F, 0x0072, 0x0071, 0x0075, 0x00E9, 0x006E, 0x006F,
    0x0070, 0x0075, 0x0065, 0x0064, 0x0065, 0x006E, 0x0073, 0x0069,
    0x006D, 0x0070, 0x006C, 0x0065, 0x006D, 0x0065, 0x006E, 0x0074,
    0x0065, 0x0068, 0x0061, 0x0062, 0x006C, 0x0061, 0x0072, 0x0065,
    0x006E, 0x0045, 0x0073, 0x0070, 0x0061, 0x00F1, 0x006F, 0x006C},
   "PorqunopuedensimplementehablarenEspaol-fmd56a", PUNYCODE_SUCCESS},
  {
   "(K) Vietnamese:", 31,
   {
    0x0054, 0x1EA1, 0x0069, 0x0073, 0x0061, 0x006F, 0x0068, 0x1ECD,
    0x006B, 0x0068, 0x00F4, 0x006E, 0x0067, 0x0074, 0x0068, 0x1EC3,
    0x0063, 0x0068, 0x1EC9, 0x006E, 0x00F3, 0x0069, 0x0074, 0x0069,
    0x1EBF, 0x006E, 0x0067, 0x0056, 0x0069, 0x1EC7, 0x0074},
   "TisaohkhngthchnitingVit-kjcr8268qyxafd2f1b9g", PUNYCODE_SUCCESS},
  {
   "(L) 3<nen>B<gumi><kinpachi><sensei>", 8,
   {
    0x0033, 0x5E74, 0x0042, 0x7D44, 0x91D1, 0x516B, 0x5148, 0x751F},
   "3B-ww4c5e180e575a65lsy2b", PUNYCODE_SUCCESS},
  {
   "(M) <amuro><namie>-with-SUPER-MONKEYS", 24,
   {
    0x5B89, 0x5BA4, 0x5948, 0x7F8E, 0x6075, 0x002D, 0x0077, 0x0069,
    0x0074, 0x0068, 0x002D, 0x0053, 0x0055, 0x0050, 0x0045, 0x0052,
    0x002D, 0x004D, 0x004F, 0x004E, 0x004B, 0x0045, 0x0059, 0x0053},
   "-with-SUPER-MONKEYS-pc58ag80a8qai00g7n9n", PUNYCODE_SUCCESS},
  {
   "(N) Hello-Another-Way-<sorezore><no><basho>", 25,
   {
    0x0048, 0x0065, 0x006C, 0x006C, 0x006F, 0x002D, 0x0041, 0x006E,
    0x006F, 0x0074, 0x0068, 0x0065, 0x0072, 0x002D, 0x0057, 0x0061,
    0x0079, 0x002D, 0x305D, 0x308C, 0x305E, 0x308C, 0x306E, 0x5834,
    0x6240},
   "Hello-Another-Way--fc4qua05auwb3674vfr0b", PUNYCODE_SUCCESS},
  {
   "(O) <hitotsu><yane><no><shita>2", 8,
   {
    0x3072, 0x3068, 0x3064, 0x5C4B, 0x6839, 0x306E, 0x4E0B, 0x0032},
   "2-u9tlzr9756bt3uc0v", PUNYCODE_SUCCESS},
  {
   "(P) Maji<de>Koi<suru>5<byou><mae>", 13,
   {
    0x004D, 0x0061, 0x006A, 0x0069, 0x3067, 0x004B, 0x006F, 0x0069,
    0x3059, 0x308B, 0x0035, 0x79D2, 0x524D},
   "MajiKoi5-783gue6qz075azm5e", PUNYCODE_SUCCESS},
  {
   "(Q) <pafii>de<runba>", 9,
   {
    0x30D1, 0x30D5, 0x30A3, 0x30FC, 0x0064, 0x0065, 0x30EB, 0x30F3, 0x30D0},
   "de-jg4avhby1noc0d", PUNYCODE_SUCCESS},
  {
   "(R) <sono><supiido><de>", 7,
   {
    0x305D, 0x306E, 0x30B9, 0x30D4, 0x30FC, 0x30C9, 0x3067},
   "d9juau41awczczp", PUNYCODE_SUCCESS},
  {
   "(S) -> $1.00 <-", 11,
   {
    0x002D, 0x003E, 0x0020, 0x0024, 0x0031, 0x002E, 0x0030, 0x0030,
    0x0020, 0x003C, 0x002D}, "-> $1.00 <--", PUNYCODE_SUCCESS}
};

void
doit (void)
{
  char *p;
  uint32_t *q;
  int rc;
  size_t i, outlen;

  p = malloc (sizeof (*p) * BUFSIZ);
  if (p == NULL)
    fail ("malloc() returned NULL\n");

  q = malloc (sizeof (*q) * BUFSIZ);
  if (q == NULL)
    fail ("malloc() returned NULL\n");

  for (i = 0; i < sizeof (punycode) / sizeof (punycode[0]); i++)
    {
      if (debug)
	printf ("PUNYCODE entry %ld: %s\n", i, punycode[i].name);

      if (debug)
	{
	  printf ("in:\n");
	  ucs4print (punycode[i].in, punycode[i].inlen);
	}

      outlen = BUFSIZ;
      rc = punycode_encode (punycode[i].inlen, punycode[i].in,
			    NULL, &outlen, p);
      if (rc != punycode[i].rc)
	{
	  fail ("punycode_encode() entry %ld failed: %d\n", i, rc);
	  if (debug)
	    printf ("FATAL\n");
	  continue;
	}

      if (rc == PUNYCODE_SUCCESS)
	p[outlen] = '\0';

      if (debug && rc == PUNYCODE_SUCCESS)
	{
	  printf ("computed out: %s\n", p);
	  printf ("expected out: %s\n", punycode[i].out);
	}
      else if (debug)
	printf ("returned %d expected %d\n", rc, punycode[i].rc);

      if (rc == PUNYCODE_SUCCESS)
	{
	  if (strlen (punycode[i].out) != strlen (p) ||
	      memcmp (punycode[i].out, p, strlen (p)) != 0)
	    {
	      fail ("punycode() entry %ld failed\n", i);
	      if (debug)
		printf ("ERROR\n");
	    }
	  else if (debug)
	    printf ("OK\n\n");
	}
      else if (debug)
	printf ("OK\n\n");

      if (debug)
	{
	  printf ("in: %s\n", punycode[i].out);
	}

      outlen = BUFSIZ;
      rc = punycode_decode (strlen (punycode[i].out), punycode[i].out,
			    &outlen, q, NULL);
      if (rc != punycode[i].rc)
	{
	  fail ("punycode() entry %ld failed: %d\n", i, rc);
	  if (debug)
	    printf ("FATAL\n");
	  continue;
	}

      if (debug && rc == PUNYCODE_SUCCESS)
	{
	  printf ("computed out:\n");
	  ucs4print (q, outlen);
	  printf ("expected out:\n");
	  ucs4print (punycode[i].in, punycode[i].inlen);
	}
      else if (debug)
	printf ("returned %d expected %d\n", rc, punycode[i].rc);

      if (rc == PUNYCODE_SUCCESS)
	{
	  if (punycode[i].inlen != outlen ||
	      memcmp (punycode[i].in, q, outlen) != 0)
	    {
	      fail ("punycode_decode() entry %ld failed\n", i);
	      if (debug)
		printf ("ERROR\n");
	    }
	  else if (debug)
	    printf ("OK\n\n");
	}
      else if (debug)
	printf ("OK\n\n");
    }

  free (q);
  free (p);
}
