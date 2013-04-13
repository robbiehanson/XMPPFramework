/* idna.c --- Prototypes for Internationalized Domain Name library.
   Copyright (C) 2002-2012 Simon Josefsson

   This file is part of GNU Libidn.

   GNU Libidn is free software: you can redistribute it and/or
   modify it under the terms of either:

     * the GNU Lesser General Public License as published by the Free
       Software Foundation; either version 3 of the License, or (at
       your option) any later version.

   or

     * the GNU General Public License as published by the Free
       Software Foundation; either version 2 of the License, or (at
       your option) any later version.

   or both in parallel, as here.

   GNU Libidn is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   General Public License for more details.

   You should have received copies of the GNU General Public License and
   the GNU Lesser General Public License along with this program.  If
   not, see <http://www.gnu.org/licenses/>. */

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <stdlib.h>
#include <string.h>
#include <stringprep.h>
#include <punycode.h>

#include "idna.h"

/* Get c_strcasecmp. */
#include <c-strcase.h>

#define DOTP(c) ((c) == 0x002E || (c) == 0x3002 ||	\
		 (c) == 0xFF0E || (c) == 0xFF61)

/* Core functions */

/**
 * idna_to_ascii_4i:
 * @in: input array with unicode code points.
 * @inlen: length of input array with unicode code points.
 * @out: output zero terminated string that must have room for at
 *       least 63 characters plus the terminating zero.
 * @flags: an #Idna_flags value, e.g., %IDNA_ALLOW_UNASSIGNED or
 *   %IDNA_USE_STD3_ASCII_RULES.
 *
 * The ToASCII operation takes a sequence of Unicode code points that
 * make up one domain label and transforms it into a sequence of code
 * points in the ASCII range (0..7F). If ToASCII succeeds, the
 * original sequence and the resulting sequence are equivalent labels.
 *
 * It is important to note that the ToASCII operation can fail. ToASCII
 * fails if any step of it fails. If any step of the ToASCII operation
 * fails on any label in a domain name, that domain name MUST NOT be used
 * as an internationalized domain name. The method for deadling with this
 * failure is application-specific.
 *
 * The inputs to ToASCII are a sequence of code points, the AllowUnassigned
 * flag, and the UseSTD3ASCIIRules flag. The output of ToASCII is either a
 * sequence of ASCII code points or a failure condition.
 *
 * ToASCII never alters a sequence of code points that are all in the ASCII
 * range to begin with (although it could fail). Applying the ToASCII
 * operation multiple times has exactly the same effect as applying it just
 * once.
 *
 * Return value: Returns 0 on success, or an #Idna_rc error code.
 */
int
idna_to_ascii_4i (const uint32_t * in, size_t inlen, char *out, int flags)
{
  size_t len, outlen;
  uint32_t *src;		/* XXX don't need to copy data? */
  int rc;

  /*
   * ToASCII consists of the following steps:
   *
   * 1. If all code points in the sequence are in the ASCII range (0..7F)
   * then skip to step 3.
   */

  {
    size_t i;
    int inasciirange;

    inasciirange = 1;
    for (i = 0; i < inlen; i++)
      if (in[i] > 0x7F)
	inasciirange = 0;
    if (inasciirange)
      {
	src = malloc (sizeof (in[0]) * (inlen + 1));
	if (src == NULL)
	  return IDNA_MALLOC_ERROR;

	memcpy (src, in, sizeof (in[0]) * inlen);
	src[inlen] = 0;

	goto step3;
      }
  }

  /*
   * 2. Perform the steps specified in [NAMEPREP] and fail if there is
   * an error. The AllowUnassigned flag is used in [NAMEPREP].
   */

  {
    char *p;

    p = stringprep_ucs4_to_utf8 (in, (ssize_t) inlen, NULL, NULL);
    if (p == NULL)
      return IDNA_MALLOC_ERROR;

    len = strlen (p);
    do
      {
	char *newp;

	len = 2 * len + 10;	/* XXX better guess? */
	newp = realloc (p, len);
	if (newp == NULL)
	  {
	    free (p);
	    return IDNA_MALLOC_ERROR;
	  }
	p = newp;

	if (flags & IDNA_ALLOW_UNASSIGNED)
	  rc = stringprep_nameprep (p, len);
	else
	  rc = stringprep_nameprep_no_unassigned (p, len);
      }
    while (rc == STRINGPREP_TOO_SMALL_BUFFER);

    if (rc != STRINGPREP_OK)
      {
	free (p);
	return IDNA_STRINGPREP_ERROR;
      }

    src = stringprep_utf8_to_ucs4 (p, -1, NULL);

    free (p);
  }

step3:
  /*
   * 3. If the UseSTD3ASCIIRules flag is set, then perform these checks:
   *
   * (a) Verify the absence of non-LDH ASCII code points; that is,
   * the absence of 0..2C, 2E..2F, 3A..40, 5B..60, and 7B..7F.
   *
   * (b) Verify the absence of leading and trailing hyphen-minus;
   * that is, the absence of U+002D at the beginning and end of
   * the sequence.
   */

  if (flags & IDNA_USE_STD3_ASCII_RULES)
    {
      size_t i;

      for (i = 0; src[i]; i++)
	if (src[i] <= 0x2C || src[i] == 0x2E || src[i] == 0x2F ||
	    (src[i] >= 0x3A && src[i] <= 0x40) ||
	    (src[i] >= 0x5B && src[i] <= 0x60) ||
	    (src[i] >= 0x7B && src[i] <= 0x7F))
	  {
	    free (src);
	    return IDNA_CONTAINS_NON_LDH;
	  }

      if (src[0] == 0x002D || (i > 0 && src[i - 1] == 0x002D))
	{
	  free (src);
	  return IDNA_CONTAINS_MINUS;
	}
    }

  /*
   * 4. If all code points in the sequence are in the ASCII range
   * (0..7F), then skip to step 8.
   */

  {
    size_t i;
    int inasciirange;

    inasciirange = 1;
    for (i = 0; src[i]; i++)
      {
	if (src[i] > 0x7F)
	  inasciirange = 0;
	/* copy string to output buffer if we are about to skip to step8 */
	if (i < 64)
	  out[i] = src[i];
      }
    if (i < 64)
      out[i] = '\0';
    if (inasciirange)
      goto step8;
  }

  /*
   * 5. Verify that the sequence does NOT begin with the ACE prefix.
   *
   */

  {
    size_t i;
    int match;

    match = 1;
    for (i = 0; match && i < strlen (IDNA_ACE_PREFIX); i++)
      if (((uint32_t) IDNA_ACE_PREFIX[i] & 0xFF) != src[i])
	match = 0;
    if (match)
      {
	free (src);
	return IDNA_CONTAINS_ACE_PREFIX;
      }
  }

  /*
   * 6. Encode the sequence using the encoding algorithm in [PUNYCODE]
   * and fail if there is an error.
   */
  for (len = 0; src[len]; len++)
    ;
  src[len] = '\0';
  outlen = 63 - strlen (IDNA_ACE_PREFIX);
  rc = punycode_encode (len, src, NULL,
			&outlen, &out[strlen (IDNA_ACE_PREFIX)]);
  if (rc != PUNYCODE_SUCCESS)
    {
      free (src);
      return IDNA_PUNYCODE_ERROR;
    }
  out[strlen (IDNA_ACE_PREFIX) + outlen] = '\0';

  /*
   * 7. Prepend the ACE prefix.
   */

  memcpy (out, IDNA_ACE_PREFIX, strlen (IDNA_ACE_PREFIX));

  /*
   * 8. Verify that the number of code points is in the range 1 to 63
   * inclusive (0 is excluded).
   */

step8:
  free (src);
  if (strlen (out) < 1 || strlen (out) > 63)
    return IDNA_INVALID_LENGTH;

  return IDNA_SUCCESS;
}

/* ToUnicode().  May realloc() utf8in.  Will free utf8in unconditionally. */
static int
idna_to_unicode_internal (char *utf8in,
			  uint32_t * out, size_t * outlen, int flags)
{
  int rc;
  char tmpout[64];
  size_t utf8len = strlen (utf8in) + 1;
  size_t addlen = 0;

  /*
   * ToUnicode consists of the following steps:
   *
   * 1. If the sequence contains any code points outside the ASCII range
   * (0..7F) then proceed to step 2, otherwise skip to step 3.
   */

  {
    size_t i;
    int inasciirange;

    inasciirange = 1;
    for (i = 0; utf8in[i]; i++)
      if (utf8in[i] & ~0x7F)
	inasciirange = 0;
    if (inasciirange)
      goto step3;
  }

  /*
   * 2. Perform the steps specified in [NAMEPREP] and fail if there is an
   * error. (If step 3 of ToASCII is also performed here, it will not
   * affect the overall behavior of ToUnicode, but it is not
   * necessary.) The AllowUnassigned flag is used in [NAMEPREP].
   */
  do
    {
      char *newp = realloc (utf8in, utf8len + addlen);
      if (newp == NULL)
	{
	  free (utf8in);
	  return IDNA_MALLOC_ERROR;
	}
      utf8in = newp;
      if (flags & IDNA_ALLOW_UNASSIGNED)
	rc = stringprep_nameprep (utf8in, utf8len + addlen);
      else
	rc = stringprep_nameprep_no_unassigned (utf8in, utf8len + addlen);
      addlen += 1;
    }
  while (rc == STRINGPREP_TOO_SMALL_BUFFER);

  if (rc != STRINGPREP_OK)
    {
      free (utf8in);
      return IDNA_STRINGPREP_ERROR;
    }

  /* 3. Verify that the sequence begins with the ACE prefix, and save a
   * copy of the sequence.
   * ... The ToASCII and ToUnicode operations MUST recognize the ACE
   prefix in a case-insensitive manner.
   */

step3:
  if (c_strncasecmp (utf8in, IDNA_ACE_PREFIX, strlen (IDNA_ACE_PREFIX)) != 0)
    {
      free (utf8in);
      return IDNA_NO_ACE_PREFIX;
    }

  /* 4. Remove the ACE prefix.
   */

  memmove (utf8in, &utf8in[strlen (IDNA_ACE_PREFIX)],
	   strlen (utf8in) - strlen (IDNA_ACE_PREFIX) + 1);

  /* 5. Decode the sequence using the decoding algorithm in [PUNYCODE]
   * and fail if there is an error. Save a copy of the result of
   * this step.
   */

  (*outlen)--;			/* reserve one for the zero */

  rc = punycode_decode (strlen (utf8in), utf8in, outlen, out, NULL);
  if (rc != PUNYCODE_SUCCESS)
    {
      free (utf8in);
      return IDNA_PUNYCODE_ERROR;
    }

  out[*outlen] = 0;		/* add zero */

  /* 6. Apply ToASCII.
   */

  rc = idna_to_ascii_4i (out, *outlen, tmpout, flags);
  if (rc != IDNA_SUCCESS)
    {
      free (utf8in);
      return rc;
    }

  /* 7. Verify that the result of step 6 matches the saved copy from
   * step 3, using a case-insensitive ASCII comparison.
   */

  if (c_strcasecmp (utf8in, tmpout + strlen (IDNA_ACE_PREFIX)) != 0)
    {
      free (utf8in);
      return IDNA_ROUNDTRIP_VERIFY_ERROR;
    }

  /* 8. Return the saved copy from step 5.
   */

  free (utf8in);
  return IDNA_SUCCESS;
}

/**
 * idna_to_unicode_44i:
 * @in: input array with unicode code points.
 * @inlen: length of input array with unicode code points.
 * @out: output array with unicode code points.
 * @outlen: on input, maximum size of output array with unicode code points,
 *          on exit, actual size of output array with unicode code points.
 * @flags: an #Idna_flags value, e.g., %IDNA_ALLOW_UNASSIGNED or
 *   %IDNA_USE_STD3_ASCII_RULES.
 *
 * The ToUnicode operation takes a sequence of Unicode code points
 * that make up one domain label and returns a sequence of Unicode
 * code points. If the input sequence is a label in ACE form, then the
 * result is an equivalent internationalized label that is not in ACE
 * form, otherwise the original sequence is returned unaltered.
 *
 * ToUnicode never fails. If any step fails, then the original input
 * sequence is returned immediately in that step.
 *
 * The Punycode decoder can never output more code points than it
 * inputs, but Nameprep can, and therefore ToUnicode can.  Note that
 * the number of octets needed to represent a sequence of code points
 * depends on the particular character encoding used.
 *
 * The inputs to ToUnicode are a sequence of code points, the
 * AllowUnassigned flag, and the UseSTD3ASCIIRules flag. The output of
 * ToUnicode is always a sequence of Unicode code points.
 *
 * Return value: Returns #Idna_rc error condition, but it must only be
 *   used for debugging purposes.  The output buffer is always
 *   guaranteed to contain the correct data according to the
 *   specification (sans malloc induced errors).  NB!  This means that
 *   you normally ignore the return code from this function, as
 *   checking it means breaking the standard.
 */
int
idna_to_unicode_44i (const uint32_t * in, size_t inlen,
		     uint32_t * out, size_t * outlen, int flags)
{
  int rc;
  size_t outlensave = *outlen;
  char *p;

  p = stringprep_ucs4_to_utf8 (in, (ssize_t) inlen, NULL, NULL);
  if (p == NULL)
    return IDNA_MALLOC_ERROR;

  rc = idna_to_unicode_internal (p, out, outlen, flags);
  if (rc != IDNA_SUCCESS)
    {
      memcpy (out, in, sizeof (in[0]) * (inlen < outlensave ?
					 inlen : outlensave));
      *outlen = inlen;
    }

  /* p is freed in idna_to_unicode_internal.  */

  return rc;
}

/* Wrappers that handle several labels */

/**
 * idna_to_ascii_4z:
 * @input: zero terminated input Unicode string.
 * @output: pointer to newly allocated output string.
 * @flags: an #Idna_flags value, e.g., %IDNA_ALLOW_UNASSIGNED or
 *   %IDNA_USE_STD3_ASCII_RULES.
 *
 * Convert UCS-4 domain name to ASCII string.  The domain name may
 * contain several labels, separated by dots.  The output buffer must
 * be deallocated by the caller.
 *
 * Return value: Returns %IDNA_SUCCESS on success, or error code.
 **/
int
idna_to_ascii_4z (const uint32_t * input, char **output, int flags)
{
  const uint32_t *start = input;
  const uint32_t *end;
  char buf[64];
  char *out = NULL;
  int rc;

  /* 1) Whenever dots are used as label separators, the following
     characters MUST be recognized as dots: U+002E (full stop),
     U+3002 (ideographic full stop), U+FF0E (fullwidth full stop),
     U+FF61 (halfwidth ideographic full stop). */

  if (input[0] == 0)
    {
      /* Handle implicit zero-length root label. */
      *output = malloc (1);
      if (!*output)
	return IDNA_MALLOC_ERROR;
      strcpy (*output, "");
      return IDNA_SUCCESS;
    }

  if (DOTP (input[0]) && input[1] == 0)
    {
      /* Handle explicit zero-length root label. */
      *output = malloc (2);
      if (!*output)
	return IDNA_MALLOC_ERROR;
      strcpy (*output, ".");
      return IDNA_SUCCESS;
    }

  *output = NULL;
  do
    {
      end = start;

      for (; *end && !DOTP (*end); end++)
	;

      if (*end == '\0' && start == end)
	{
	  /* Handle explicit zero-length root label. */
	  buf[0] = '\0';
	}
      else
	{
	  rc = idna_to_ascii_4i (start, (size_t) (end - start), buf, flags);
	  if (rc != IDNA_SUCCESS)
	    {
	      free (out);
	      return rc;
	    }
	}

      if (out)
	{
	  size_t l = strlen (out) + 1 + strlen (buf) + 1;
	  char *newp = realloc (out, l);
	  if (!newp)
	    {
	      free (out);
	      return IDNA_MALLOC_ERROR;
	    }
	  out = newp;
	  strcat (out, ".");
	  strcat (out, buf);
	}
      else
	{
	  size_t l = strlen (buf) + 1;
	  out = (char *) malloc (l);
	  if (!out)
	    return IDNA_MALLOC_ERROR;
	  strcpy (out, buf);
	}

      start = end + 1;
    }
  while (*end);

  *output = out;

  return IDNA_SUCCESS;
}

/**
 * idna_to_ascii_8z:
 * @input: zero terminated input UTF-8 string.
 * @output: pointer to newly allocated output string.
 * @flags: an #Idna_flags value, e.g., %IDNA_ALLOW_UNASSIGNED or
 *   %IDNA_USE_STD3_ASCII_RULES.
 *
 * Convert UTF-8 domain name to ASCII string.  The domain name may
 * contain several labels, separated by dots.  The output buffer must
 * be deallocated by the caller.
 *
 * Return value: Returns %IDNA_SUCCESS on success, or error code.
 **/
int
idna_to_ascii_8z (const char *input, char **output, int flags)
{
  uint32_t *ucs4;
  size_t ucs4len;
  int rc;

  ucs4 = stringprep_utf8_to_ucs4 (input, -1, &ucs4len);
  if (!ucs4)
    return IDNA_ICONV_ERROR;

  rc = idna_to_ascii_4z (ucs4, output, flags);

  free (ucs4);

  return rc;

}

/**
 * idna_to_ascii_lz:
 * @input: zero terminated input string encoded in the current locale's
 *   character set.
 * @output: pointer to newly allocated output string.
 * @flags: an #Idna_flags value, e.g., %IDNA_ALLOW_UNASSIGNED or
 *   %IDNA_USE_STD3_ASCII_RULES.
 *
 * Convert domain name in the locale's encoding to ASCII string.  The
 * domain name may contain several labels, separated by dots.  The
 * output buffer must be deallocated by the caller.
 *
 * Return value: Returns %IDNA_SUCCESS on success, or error code.
 **/
int
idna_to_ascii_lz (const char *input, char **output, int flags)
{
  char *utf8;
  int rc;

  utf8 = stringprep_locale_to_utf8 (input);
  if (!utf8)
    return IDNA_ICONV_ERROR;

  rc = idna_to_ascii_8z (utf8, output, flags);

  free (utf8);

  return rc;
}

/**
 * idna_to_unicode_4z4z:
 * @input: zero-terminated Unicode string.
 * @output: pointer to newly allocated output Unicode string.
 * @flags: an #Idna_flags value, e.g., %IDNA_ALLOW_UNASSIGNED or
 *   %IDNA_USE_STD3_ASCII_RULES.
 *
 * Convert possibly ACE encoded domain name in UCS-4 format into a
 * UCS-4 string.  The domain name may contain several labels,
 * separated by dots.  The output buffer must be deallocated by the
 * caller.
 *
 * Return value: Returns %IDNA_SUCCESS on success, or error code.
 **/
int
idna_to_unicode_4z4z (const uint32_t * input, uint32_t ** output, int flags)
{
  const uint32_t *start = input;
  const uint32_t *end;
  uint32_t *buf;
  size_t buflen;
  uint32_t *out = NULL;
  size_t outlen = 0;

  *output = NULL;

  do
    {
      end = start;

      for (; *end && !DOTP (*end); end++)
	;

      buflen = (size_t) (end - start);
      buf = malloc (sizeof (buf[0]) * (buflen + 1));
      if (!buf)
	return IDNA_MALLOC_ERROR;

      /* don't check return code as per specification! */
      idna_to_unicode_44i (start, (size_t) (end - start),
			   buf, &buflen, flags);

      if (out)
	{
	  uint32_t *newp = realloc (out,
				    sizeof (out[0])
				    * (outlen + 1 + buflen + 1));
	  if (!newp)
	    {
	      free (buf);
	      free (out);
	      return IDNA_MALLOC_ERROR;
	    }
	  out = newp;
	  out[outlen++] = 0x002E;	/* '.' (full stop) */
	  memcpy (out + outlen, buf, sizeof (buf[0]) * buflen);
	  outlen += buflen;
	  out[outlen] = 0x0;
	  free (buf);
	}
      else
	{
	  out = buf;
	  outlen = buflen;
	  out[outlen] = 0x0;
	}

      start = end + 1;
    }
  while (*end);

  *output = out;

  return IDNA_SUCCESS;
}

/**
 * idna_to_unicode_8z4z:
 * @input: zero-terminated UTF-8 string.
 * @output: pointer to newly allocated output Unicode string.
 * @flags: an #Idna_flags value, e.g., %IDNA_ALLOW_UNASSIGNED or
 *   %IDNA_USE_STD3_ASCII_RULES.
 *
 * Convert possibly ACE encoded domain name in UTF-8 format into a
 * UCS-4 string.  The domain name may contain several labels,
 * separated by dots.  The output buffer must be deallocated by the
 * caller.
 *
 * Return value: Returns %IDNA_SUCCESS on success, or error code.
 **/
int
idna_to_unicode_8z4z (const char *input, uint32_t ** output, int flags)
{
  uint32_t *ucs4;
  size_t ucs4len;
  int rc;

  ucs4 = stringprep_utf8_to_ucs4 (input, -1, &ucs4len);
  if (!ucs4)
    return IDNA_ICONV_ERROR;

  rc = idna_to_unicode_4z4z (ucs4, output, flags);
  free (ucs4);

  return rc;
}

/**
 * idna_to_unicode_8z8z:
 * @input: zero-terminated UTF-8 string.
 * @output: pointer to newly allocated output UTF-8 string.
 * @flags: an #Idna_flags value, e.g., %IDNA_ALLOW_UNASSIGNED or
 *   %IDNA_USE_STD3_ASCII_RULES.
 *
 * Convert possibly ACE encoded domain name in UTF-8 format into a
 * UTF-8 string.  The domain name may contain several labels,
 * separated by dots.  The output buffer must be deallocated by the
 * caller.
 *
 * Return value: Returns %IDNA_SUCCESS on success, or error code.
 **/
int
idna_to_unicode_8z8z (const char *input, char **output, int flags)
{
  uint32_t *ucs4;
  int rc;

  rc = idna_to_unicode_8z4z (input, &ucs4, flags);
  *output = stringprep_ucs4_to_utf8 (ucs4, -1, NULL, NULL);
  free (ucs4);

  if (!*output)
    return IDNA_ICONV_ERROR;

  return rc;
}

/**
 * idna_to_unicode_8zlz:
 * @input: zero-terminated UTF-8 string.
 * @output: pointer to newly allocated output string encoded in the
 *   current locale's character set.
 * @flags: an #Idna_flags value, e.g., %IDNA_ALLOW_UNASSIGNED or
 *   %IDNA_USE_STD3_ASCII_RULES.
 *
 * Convert possibly ACE encoded domain name in UTF-8 format into a
 * string encoded in the current locale's character set.  The domain
 * name may contain several labels, separated by dots.  The output
 * buffer must be deallocated by the caller.
 *
 * Return value: Returns %IDNA_SUCCESS on success, or error code.
 **/
int
idna_to_unicode_8zlz (const char *input, char **output, int flags)
{
  char *utf8;
  int rc;

  rc = idna_to_unicode_8z8z (input, &utf8, flags);
  *output = stringprep_utf8_to_locale (utf8);
  free (utf8);

  if (!*output)
    return IDNA_ICONV_ERROR;

  return rc;
}

/**
 * idna_to_unicode_lzlz:
 * @input: zero-terminated string encoded in the current locale's
 *   character set.
 * @output: pointer to newly allocated output string encoded in the
 *   current locale's character set.
 * @flags: an #Idna_flags value, e.g., %IDNA_ALLOW_UNASSIGNED or
 *   %IDNA_USE_STD3_ASCII_RULES.
 *
 * Convert possibly ACE encoded domain name in the locale's character
 * set into a string encoded in the current locale's character set.
 * The domain name may contain several labels, separated by dots.  The
 * output buffer must be deallocated by the caller.
 *
 * Return value: Returns %IDNA_SUCCESS on success, or error code.
 **/
int
idna_to_unicode_lzlz (const char *input, char **output, int flags)
{
  char *utf8;
  int rc;

  utf8 = stringprep_locale_to_utf8 (input);
  if (!utf8)
    return IDNA_ICONV_ERROR;

  rc = idna_to_unicode_8zlz (utf8, output, flags);
  free (utf8);

  return rc;
}

/**
 * IDNA_ACE_PREFIX
 *
 * The IANA allocated prefix to use for IDNA. "xn--"
 */

/**
 * Idna_rc:
 * @IDNA_SUCCESS: Successful operation.  This value is guaranteed to
 *   always be zero, the remaining ones are only guaranteed to hold
 *   non-zero values, for logical comparison purposes.
 * @IDNA_STRINGPREP_ERROR:  Error during string preparation.
 * @IDNA_PUNYCODE_ERROR: Error during punycode operation.
 * @IDNA_CONTAINS_NON_LDH: For IDNA_USE_STD3_ASCII_RULES, indicate that
 *   the string contains non-LDH ASCII characters.
 * @IDNA_CONTAINS_LDH: Same as @IDNA_CONTAINS_NON_LDH, for compatibility
 *   with typo in earlier versions.
 * @IDNA_CONTAINS_MINUS: For IDNA_USE_STD3_ASCII_RULES, indicate that
 *   the string contains a leading or trailing hyphen-minus (U+002D).
 * @IDNA_INVALID_LENGTH: The final output string is not within the
 *   (inclusive) range 1 to 63 characters.
 * @IDNA_NO_ACE_PREFIX: The string does not contain the ACE prefix
 *   (for ToUnicode).
 * @IDNA_ROUNDTRIP_VERIFY_ERROR: The ToASCII operation on output
 *   string does not equal the input.
 * @IDNA_CONTAINS_ACE_PREFIX: The input contains the ACE prefix (for
 *   ToASCII).
 * @IDNA_ICONV_ERROR: Could not convert string in locale encoding.
 * @IDNA_MALLOC_ERROR: Could not allocate buffer (this is typically a
 *   fatal error).
 * @IDNA_DLOPEN_ERROR: Could not dlopen the libcidn DSO (only used
 *   internally in libc).
 *
 * Enumerated return codes of idna_to_ascii_4i(),
 * idna_to_unicode_44i() functions (and functions derived from those
 * functions).  The value 0 is guaranteed to always correspond to
 * success.
 */


/**
 * Idna_flags:
 * @IDNA_ALLOW_UNASSIGNED: Don't reject strings containing unassigned
 *   Unicode code points.
 * @IDNA_USE_STD3_ASCII_RULES: Validate strings according to STD3
 *   rules (i.e., normal host name rules).
 *
 * Flags to pass to idna_to_ascii_4i(), idna_to_unicode_44i() etc.
 */
