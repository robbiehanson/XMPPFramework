/* tld.c --- Declarations for TLD restriction checking.
   Copyright (C) 2004-2012 Simon Josefsson.
   Copyright (C) 2003-2012 Free Software Foundation, Inc.

   Author: Thomas Jacob, Internet24.de

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

#include <config.h>

/* Get stringprep_utf8_to_ucs4, stringprep_locale_to_utf8. */
#include <stringprep.h>

/* Get strcmp(). */
#include <string.h>

/* Get specifications. */
#include <tld.h>

/* Array of built-in domain restriction structures.  See tlds.c.  */
extern const Tld_table *_tld_tables[];

/**
 * tld_get_table:
 * @tld: TLD name (e.g. "com") as zero terminated ASCII byte string.
 * @tables: Zero terminated array of #Tld_table info-structures for
 *   TLDs.
 *
 * Get the TLD table for a named TLD by searching through the given
 * TLD table array.
 *
 * Return value: Return structure corresponding to TLD @tld by going
 *   thru @tables, or return %NULL if no such structure is found.
 */
const Tld_table *
tld_get_table (const char *tld, const Tld_table ** tables)
{
  const Tld_table **tldtable = NULL;

  if (!tld || !tables)
    return NULL;

  for (tldtable = tables; *tldtable; tldtable++)
    if (!strcmp ((*tldtable)->name, tld))
      return *tldtable;

  return NULL;
}

/**
 * tld_default_table:
 * @tld: TLD name (e.g. "com") as zero terminated ASCII byte string.
 * @overrides: Additional zero terminated array of #Tld_table
 *   info-structures for TLDs, or %NULL to only use library deault
 *   tables.
 *
 * Get the TLD table for a named TLD, using the internal defaults,
 * possibly overrided by the (optional) supplied tables.
 *
 * Return value: Return structure corresponding to TLD @tld_str, first
 *   looking through @overrides then thru built-in list, or %NULL if
 *   no such structure found.
 */
const Tld_table *
tld_default_table (const char *tld, const Tld_table ** overrides)
{
  const Tld_table *tldtable = NULL;

  if (!tld)
    return NULL;

  if (overrides)
    tldtable = tld_get_table (tld, overrides);

  if (!tldtable)
    tldtable = tld_get_table (tld, _tld_tables);

  return tldtable;
}

#define DOTP(c) ((c) == 0x002E || (c) == 0x3002 ||	\
		 (c) == 0xFF0E || (c) == 0xFF61)

/**
 * tld_get_4:
 * @in: Array of unicode code points to process. Does not need to be
 *   zero terminated.
 * @inlen: Number of unicode code points.
 * @out: Zero terminated ascii result string pointer.
 *
 * Isolate the top-level domain of @in and return it as an ASCII
 * string in @out.
 *
 * Return value: Return %TLD_SUCCESS on success, or the corresponding
 *   #Tld_rc error code otherwise.
 */
int
tld_get_4 (const uint32_t * in, size_t inlen, char **out)
{
  const uint32_t *ipos;
  size_t olen;

  *out = NULL;
  if (!in || inlen == 0)
    return TLD_NODATA;

  ipos = &in[inlen - 1];
  olen = 0;
  /* Scan backwards for non(latin)letters. */
  while (ipos >= in && ((*ipos >= 0x41 && *ipos <= 0x5A) ||
			(*ipos >= 0x61 && *ipos <= 0x7A)))
    ipos--, olen++;

  if (olen > 0 && DOTP (*ipos))	/* Found something that appears a TLD. */
    {
      char *out_s = malloc (sizeof (char) * (olen + 1));
      char *opos = out_s;

      if (!opos)
	return TLD_MALLOC_ERROR;

      ipos++;
      /* Transcribe to lowercase ascii string. */
      for (; ipos < &in[inlen]; ipos++, opos++)
	*opos = *ipos > 0x5A ? *ipos : *ipos + 0x20;
      *opos = 0;
      *out = out_s;
      return TLD_SUCCESS;
    }

  return TLD_NO_TLD;
}

/**
 * tld_get_4z:
 * @in: Zero terminated array of unicode code points to process.
 * @out: Zero terminated ascii result string pointer.
 *
 * Isolate the top-level domain of @in and return it as an ASCII
 * string in @out.
 *
 * Return value: Return %TLD_SUCCESS on success, or the corresponding
 *   #Tld_rc error code otherwise.
 */
int
tld_get_4z (const uint32_t * in, char **out)
{
  const uint32_t *ipos = in;

  if (!in)
    return TLD_NODATA;

  while (*ipos)
    ipos++;

  return tld_get_4 (in, ipos - in, out);
}

/**
 * tld_get_z:
 * @in: Zero terminated character array to process.
 * @out: Zero terminated ascii result string pointer.
 *
 * Isolate the top-level domain of @in and return it as an ASCII
 * string in @out.  The input string @in may be UTF-8, ISO-8859-1 or
 * any ASCII compatible character encoding.
 *
 * Return value: Return %TLD_SUCCESS on success, or the corresponding
 *   #Tld_rc error code otherwise.
 */
int
tld_get_z (const char *in, char **out)
{
  uint32_t *iucs;
  size_t i, ilen;
  int rc;

  ilen = strlen (in);
  iucs = calloc (ilen, sizeof (*iucs));

  if (!iucs)
    return TLD_MALLOC_ERROR;

  for (i = 0; i < ilen; i++)
    iucs[i] = in[i];

  rc = tld_get_4 (iucs, ilen, out);

  free (iucs);

  return rc;
}

/*
 * tld_checkchar - verify that character is permitted
 * @ch: 32 bit unicode character to check.
 * @tld: A #Tld_table data structure to check @ch against.
 *
 * Verify if @ch is either in [a-z0-9-.] or mentioned as a valid
 * character in @tld.
 *
 * Return value: Return the #Tld_rc value %TLD_SUCCESS if @ch is a
 *   valid character for the TLD @tld or if @tld is %NULL,
 *   %TLD_INVALID if @ch is invalid as defined by @tld.
 */
static int
_tld_checkchar (uint32_t ch, const Tld_table * tld)
{
  const Tld_table_element *s, *e, *m;

  if (!tld)
    return TLD_SUCCESS;

  /* Check for [-a-z0-9.]. */
  if ((ch >= 0x61 && ch <= 0x7A) ||
      (ch >= 0x30 && ch <= 0x39) || ch == 0x2D || DOTP (ch))
    return TLD_SUCCESS;

  s = tld->valid;
  e = s + tld->nvalid;
  while (s < e)
    {
      m = s + ((e - s) >> 1);
      if (ch < m->start)
	e = m;
      else if (ch > m->end)
	s = m + 1;
      else
	return TLD_SUCCESS;
    }

  return TLD_INVALID;
}

/**
 * tld_check_4t:
 * @in: Array of unicode code points to process. Does not need to be
 *   zero terminated.
 * @inlen: Number of unicode code points.
 * @errpos: Position of offending character is returned here.
 * @tld: A #Tld_table data structure representing the restrictions for
 *   which the input should be tested.
 *
 * Test each of the code points in @in for whether or not
 * they are allowed by the data structure in @tld, return
 * the position of the first character for which this is not
 * the case in @errpos.
 *
 * Return value: Returns the #Tld_rc value %TLD_SUCCESS if all code
 *   points are valid or when @tld is null, %TLD_INVALID if a
 *   character is not allowed, or additional error codes on general
 *   failure conditions.
 */
int
tld_check_4t (const uint32_t * in, size_t inlen, size_t * errpos,
	      const Tld_table * tld)
{
  const uint32_t *ipos;
  int rc;

  if (!tld)			/* No data for TLD so everything is valid. */
    return TLD_SUCCESS;

  ipos = in;
  while (ipos < &in[inlen])
    {
      rc = _tld_checkchar (*ipos, tld);
      if (rc != TLD_SUCCESS)
	{
	  if (errpos)
	    *errpos = ipos - in;
	  return rc;
	}
      ipos++;
    }
  return TLD_SUCCESS;
}

/**
 * tld_check_4tz:
 * @in: Zero terminated array of unicode code points to process.
 * @errpos: Position of offending character is returned here.
 * @tld: A #Tld_table data structure representing the restrictions for
 *   which the input should be tested.
 *
 * Test each of the code points in @in for whether or not
 * they are allowed by the data structure in @tld, return
 * the position of the first character for which this is not
 * the case in @errpos.
 *
 * Return value: Returns the #Tld_rc value %TLD_SUCCESS if all code
 *   points are valid or when @tld is null, %TLD_INVALID if a
 *   character is not allowed, or additional error codes on general
 *   failure conditions.
 */
int
tld_check_4tz (const uint32_t * in, size_t * errpos, const Tld_table * tld)
{
  const uint32_t *ipos = in;

  if (!ipos)
    return TLD_NODATA;

  while (*ipos)
    ipos++;

  return tld_check_4t (in, ipos - in, errpos, tld);
}

/**
 * tld_check_4:
 * @in: Array of unicode code points to process. Does not need to be
 *   zero terminated.
 * @inlen: Number of unicode code points.
 * @errpos: Position of offending character is returned here.
 * @overrides: A #Tld_table array of additional domain restriction
 *  structures that complement and supersede the built-in information.
 *
 * Test each of the code points in @in for whether or not they are
 * allowed by the information in @overrides or by the built-in TLD
 * restriction data. When data for the same TLD is available both
 * internally and in @overrides, the information in @overrides takes
 * precedence. If several entries for a specific TLD are found, the
 * first one is used.  If @overrides is %NULL, only the built-in
 * information is used.  The position of the first offending character
 * is returned in @errpos.
 *
 * Return value: Returns the #Tld_rc value %TLD_SUCCESS if all code
 *   points are valid or when @tld is null, %TLD_INVALID if a
 *   character is not allowed, or additional error codes on general
 *   failure conditions.
 */
int
tld_check_4 (const uint32_t * in, size_t inlen, size_t * errpos,
	     const Tld_table ** overrides)
{
  const Tld_table *tld;
  char *domain;
  int rc;

  if (errpos)
    *errpos = 0;

  /* Get TLD name. */
  rc = tld_get_4 (in, inlen, &domain);

  if (rc != TLD_SUCCESS)
    {
      if (rc == TLD_NO_TLD)	/* No TLD, say OK */
	return TLD_SUCCESS;
      else
	return rc;
    }

  /* Retrieve appropriate data structure. */
  tld = tld_default_table (domain, overrides);
  free (domain);

  return tld_check_4t (in, inlen, errpos, tld);
}

/**
 * tld_check_4z:
 * @in: Zero-terminated array of unicode code points to process.
 * @errpos: Position of offending character is returned here.
 * @overrides: A #Tld_table array of additional domain restriction
 *   structures that complement and supersede the built-in information.
 *
 * Test each of the code points in @in for whether or not they are
 * allowed by the information in @overrides or by the built-in TLD
 * restriction data. When data for the same TLD is available both
 * internally and in @overrides, the information in @overrides takes
 * precedence. If several entries for a specific TLD are found, the
 * first one is used.  If @overrides is %NULL, only the built-in
 * information is used.  The position of the first offending character
 * is returned in @errpos.
 *
 * Return value: Returns the #Tld_rc value %TLD_SUCCESS if all code
 *   points are valid or when @tld is null, %TLD_INVALID if a
 *   character is not allowed, or additional error codes on general
 *   failure conditions.
 */
int
tld_check_4z (const uint32_t * in, size_t * errpos,
	      const Tld_table ** overrides)
{
  const uint32_t *ipos = in;

  if (!ipos)
    return TLD_NODATA;

  while (*ipos)
    ipos++;

  return tld_check_4 (in, ipos - in, errpos, overrides);
}

/**
 * tld_check_8z:
 * @in: Zero-terminated UTF8 string to process.
 * @errpos: Position of offending character is returned here.
 * @overrides: A #Tld_table array of additional domain restriction
 *   structures that complement and supersede the built-in information.
 *
 * Test each of the characters in @in for whether or not they are
 * allowed by the information in @overrides or by the built-in TLD
 * restriction data. When data for the same TLD is available both
 * internally and in @overrides, the information in @overrides takes
 * precedence. If several entries for a specific TLD are found, the
 * first one is used.  If @overrides is %NULL, only the built-in
 * information is used.  The position of the first offending character
 * is returned in @errpos.  Note that the error position refers to the
 * decoded character offset rather than the byte position in the
 * string.
 *
 * Return value: Returns the #Tld_rc value %TLD_SUCCESS if all
 *   characters are valid or when @tld is null, %TLD_INVALID if a
 *   character is not allowed, or additional error codes on general
 *   failure conditions.
 */
int
tld_check_8z (const char *in, size_t * errpos, const Tld_table ** overrides)
{
  uint32_t *iucs;
  size_t ilen;
  int rc;

  if (!in)
    return TLD_NODATA;

  iucs = stringprep_utf8_to_ucs4 (in, -1, &ilen);

  if (!iucs)
    return TLD_MALLOC_ERROR;

  rc = tld_check_4 (iucs, ilen, errpos, overrides);

  free (iucs);

  return rc;
}

/**
 * tld_check_lz:
 * @in: Zero-terminated string in the current locales encoding to process.
 * @errpos: Position of offending character is returned here.
 * @overrides: A #Tld_table array of additional domain restriction
 *   structures that complement and supersede the built-in information.
 *
 * Test each of the characters in @in for whether or not they are
 * allowed by the information in @overrides or by the built-in TLD
 * restriction data. When data for the same TLD is available both
 * internally and in @overrides, the information in @overrides takes
 * precedence. If several entries for a specific TLD are found, the
 * first one is used.  If @overrides is %NULL, only the built-in
 * information is used.  The position of the first offending character
 * is returned in @errpos.  Note that the error position refers to the
 * decoded character offset rather than the byte position in the
 * string.
 *
 * Return value: Returns the #Tld_rc value %TLD_SUCCESS if all
 *   characters are valid or when @tld is null, %TLD_INVALID if a
 *   character is not allowed, or additional error codes on general
 *   failure conditions.
 */
int
tld_check_lz (const char *in, size_t * errpos, const Tld_table ** overrides)
{
  char *utf8;
  int rc;

  if (!in)
    return TLD_NODATA;

  utf8 = stringprep_locale_to_utf8 (in);
  if (!utf8)
    return TLD_ICONV_ERROR;


  rc = tld_check_8z (utf8, errpos, overrides);

  free (utf8);

  return rc;
}

/**
 * Tld_rc:
 * @TLD_SUCCESS: Successful operation.  This value is guaranteed to
 *   always be zero, the remaining ones are only guaranteed to hold
 *   non-zero values, for logical comparison purposes.
 * @TLD_INVALID: Invalid character found.
 * @TLD_NODATA: No input data was provided.
 * @TLD_MALLOC_ERROR: Error during memory allocation.
 * @TLD_ICONV_ERROR: Error during iconv string conversion.
 * @TLD_NO_TLD: No top-level domain found in domain string.
 * @TLD_NOTLD: Same as @TLD_NO_TLD, for compatibility
 *   with typo in earlier versions.
 *
 * Enumerated return codes of the TLD checking functions.
 * The value 0 is guaranteed to always correspond to success.
 */
