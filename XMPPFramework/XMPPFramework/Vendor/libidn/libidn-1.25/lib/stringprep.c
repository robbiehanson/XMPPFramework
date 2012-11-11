/* stringprep.c --- Core stringprep implementation.
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

#include "stringprep.h"

static ssize_t
stringprep_find_character_in_table (uint32_t ucs4,
				    const Stringprep_table_element * table)
{
  ssize_t i;

  /* This is where typical uses of Libidn spends very close to all CPU
     time and causes most cache misses.  One could easily do a binary
     search instead.  Before rewriting this, I want hard evidence this
     slowness is at all relevant in typical applications.  (I don't
     dispute optimization may improve matters significantly, I'm
     mostly interested in having someone give real-world benchmark on
     the impact of libidn.) */

  for (i = 0; table[i].start || table[i].end; i++)
    if (ucs4 >= table[i].start &&
	ucs4 <= (table[i].end ? table[i].end : table[i].start))
      return i;

  return -1;
}

static ssize_t
stringprep_find_string_in_table (uint32_t * ucs4,
				 size_t ucs4len,
				 size_t * tablepos,
				 const Stringprep_table_element * table)
{
  size_t j;
  ssize_t pos;

  for (j = 0; j < ucs4len; j++)
    if ((pos = stringprep_find_character_in_table (ucs4[j], table)) != -1)
      {
	if (tablepos)
	  *tablepos = pos;
	return j;
      }

  return -1;
}

static int
stringprep_apply_table_to_string (uint32_t * ucs4,
				  size_t * ucs4len,
				  size_t maxucs4len,
				  const Stringprep_table_element * table)
{
  ssize_t pos;
  size_t i, maplen;

  while ((pos = stringprep_find_string_in_table (ucs4, *ucs4len,
						 &i, table)) != -1)
    {
      for (maplen = STRINGPREP_MAX_MAP_CHARS;
	   maplen > 0 && table[i].map[maplen - 1] == 0; maplen--)
	;

      if (*ucs4len - 1 + maplen >= maxucs4len)
	return STRINGPREP_TOO_SMALL_BUFFER;

      memmove (&ucs4[pos + maplen], &ucs4[pos + 1],
	       sizeof (uint32_t) * (*ucs4len - pos - 1));
      memcpy (&ucs4[pos], table[i].map, sizeof (uint32_t) * maplen);
      *ucs4len = *ucs4len - 1 + maplen;
    }

  return STRINGPREP_OK;
}

#define INVERTED(x) ((x) & ((~0UL) >> 1))
#define UNAPPLICAPLEFLAGS(flags, profileflags) \
  ((!INVERTED(profileflags) && !(profileflags & flags) && profileflags) || \
   ( INVERTED(profileflags) && (profileflags & flags)))

/**
 * stringprep_4i:
 * @ucs4: input/output array with string to prepare.
 * @len: on input, length of input array with Unicode code points,
 *   on exit, length of output array with Unicode code points.
 * @maxucs4len: maximum length of input/output array.
 * @flags: a #Stringprep_profile_flags value, or 0.
 * @profile: pointer to #Stringprep_profile to use.
 *
 * Prepare the input UCS-4 string according to the stringprep profile,
 * and write back the result to the input string.
 *
 * The input is not required to be zero terminated (@ucs4[@len] = 0).
 * The output will not be zero terminated unless @ucs4[@len] = 0.
 * Instead, see stringprep_4zi() if your input is zero terminated or
 * if you want the output to be.
 *
 * Since the stringprep operation can expand the string, @maxucs4len
 * indicate how large the buffer holding the string is.  This function
 * will not read or write to code points outside that size.
 *
 * The @flags are one of #Stringprep_profile_flags values, or 0.
 *
 * The @profile contain the #Stringprep_profile instructions to
 * perform.  Your application can define new profiles, possibly
 * re-using the generic stringprep tables that always will be part of
 * the library, or use one of the currently supported profiles.
 *
 * Return value: Returns %STRINGPREP_OK iff successful, or an
 *   #Stringprep_rc error code.
 **/
int
stringprep_4i (uint32_t * ucs4, size_t * len, size_t maxucs4len,
	       Stringprep_profile_flags flags,
	       const Stringprep_profile * profile)
{
  size_t i, j;
  ssize_t k;
  size_t ucs4len = *len;
  int rc;

  for (i = 0; profile[i].operation; i++)
    {
      switch (profile[i].operation)
	{
	case STRINGPREP_NFKC:
	  {
	    uint32_t *q = 0;

	    if (UNAPPLICAPLEFLAGS (flags, profile[i].flags))
	      break;

	    if (flags & STRINGPREP_NO_NFKC && !profile[i].flags)
	      /* Profile requires NFKC, but callee asked for no NFKC. */
	      return STRINGPREP_FLAG_ERROR;

	    q = stringprep_ucs4_nfkc_normalize (ucs4, ucs4len);
	    if (!q)
	      return STRINGPREP_NFKC_FAILED;

	    for (ucs4len = 0; q[ucs4len]; ucs4len++)
	      ;

	    if (ucs4len >= maxucs4len)
	      {
		free (q);
		return STRINGPREP_TOO_SMALL_BUFFER;
	      }

	    memcpy (ucs4, q, ucs4len * sizeof (ucs4[0]));

	    free (q);
	  }
	  break;

	case STRINGPREP_PROHIBIT_TABLE:
	  k = stringprep_find_string_in_table (ucs4, ucs4len,
					       NULL, profile[i].table);
	  if (k != -1)
	    return STRINGPREP_CONTAINS_PROHIBITED;
	  break;

	case STRINGPREP_UNASSIGNED_TABLE:
	  if (UNAPPLICAPLEFLAGS (flags, profile[i].flags))
	    break;
	  if (flags & STRINGPREP_NO_UNASSIGNED)
	    {
	      k = stringprep_find_string_in_table
		(ucs4, ucs4len, NULL, profile[i].table);
	      if (k != -1)
		return STRINGPREP_CONTAINS_UNASSIGNED;
	    }
	  break;

	case STRINGPREP_MAP_TABLE:
	  if (UNAPPLICAPLEFLAGS (flags, profile[i].flags))
	    break;
	  rc = stringprep_apply_table_to_string
	    (ucs4, &ucs4len, maxucs4len, profile[i].table);
	  if (rc != STRINGPREP_OK)
	    return rc;
	  break;

	case STRINGPREP_BIDI_PROHIBIT_TABLE:
	case STRINGPREP_BIDI_RAL_TABLE:
	case STRINGPREP_BIDI_L_TABLE:
	  break;

	case STRINGPREP_BIDI:
	  {
	    int done_prohibited = 0;
	    int done_ral = 0;
	    int done_l = 0;
	    size_t contains_ral = SIZE_MAX;
	    size_t contains_l = SIZE_MAX;

	    for (j = 0; profile[j].operation; j++)
	      if (profile[j].operation == STRINGPREP_BIDI_PROHIBIT_TABLE)
		{
		  done_prohibited = 1;
		  k = stringprep_find_string_in_table (ucs4, ucs4len,
						       NULL,
						       profile[j].table);
		  if (k != -1)
		    return STRINGPREP_BIDI_CONTAINS_PROHIBITED;
		}
	      else if (profile[j].operation == STRINGPREP_BIDI_RAL_TABLE)
		{
		  done_ral = 1;
		  if (stringprep_find_string_in_table
		      (ucs4, ucs4len, NULL, profile[j].table) != -1)
		    contains_ral = j;
		}
	      else if (profile[j].operation == STRINGPREP_BIDI_L_TABLE)
		{
		  done_l = 1;
		  if (stringprep_find_string_in_table
		      (ucs4, ucs4len, NULL, profile[j].table) != -1)
		    contains_l = j;
		}

	    if (!done_prohibited || !done_ral || !done_l)
	      return STRINGPREP_PROFILE_ERROR;

	    if (contains_ral != SIZE_MAX && contains_l != SIZE_MAX)
	      return STRINGPREP_BIDI_BOTH_L_AND_RAL;

	    if (contains_ral != SIZE_MAX)
	      {
		if (!(stringprep_find_character_in_table
		      (ucs4[0], profile[contains_ral].table) != -1 &&
		      stringprep_find_character_in_table
		      (ucs4[ucs4len - 1], profile[contains_ral].table) != -1))
		  return STRINGPREP_BIDI_LEADTRAIL_NOT_RAL;
	      }
	  }
	  break;

	default:
	  return STRINGPREP_PROFILE_ERROR;
	  break;
	}
    }

  *len = ucs4len;

  return STRINGPREP_OK;
}

static int
stringprep_4zi_1 (uint32_t * ucs4, size_t ucs4len, size_t maxucs4len,
		  Stringprep_profile_flags flags,
		  const Stringprep_profile * profile)
{
  int rc;

  rc = stringprep_4i (ucs4, &ucs4len, maxucs4len, flags, profile);
  if (rc != STRINGPREP_OK)
    return rc;

  if (ucs4len >= maxucs4len)
    return STRINGPREP_TOO_SMALL_BUFFER;

  ucs4[ucs4len] = 0;

  return STRINGPREP_OK;
}

/**
 * stringprep_4zi:
 * @ucs4: input/output array with zero terminated string to prepare.
 * @maxucs4len: maximum length of input/output array.
 * @flags: a #Stringprep_profile_flags value, or 0.
 * @profile: pointer to #Stringprep_profile to use.
 *
 * Prepare the input zero terminated UCS-4 string according to the
 * stringprep profile, and write back the result to the input string.
 *
 * Since the stringprep operation can expand the string, @maxucs4len
 * indicate how large the buffer holding the string is.  This function
 * will not read or write to code points outside that size.
 *
 * The @flags are one of #Stringprep_profile_flags values, or 0.
 *
 * The @profile contain the #Stringprep_profile instructions to
 * perform.  Your application can define new profiles, possibly
 * re-using the generic stringprep tables that always will be part of
 * the library, or use one of the currently supported profiles.
 *
 * Return value: Returns %STRINGPREP_OK iff successful, or an
 *   #Stringprep_rc error code.
 **/
int
stringprep_4zi (uint32_t * ucs4, size_t maxucs4len,
		Stringprep_profile_flags flags,
		const Stringprep_profile * profile)
{
  size_t ucs4len;

  for (ucs4len = 0; ucs4len < maxucs4len && ucs4[ucs4len] != 0; ucs4len++)
    ;

  return stringprep_4zi_1 (ucs4, ucs4len, maxucs4len, flags, profile);
}

/**
 * stringprep:
 * @in: input/ouput array with string to prepare.
 * @maxlen: maximum length of input/output array.
 * @flags: a #Stringprep_profile_flags value, or 0.
 * @profile: pointer to #Stringprep_profile to use.
 *
 * Prepare the input zero terminated UTF-8 string according to the
 * stringprep profile, and write back the result to the input string.
 *
 * Note that you must convert strings entered in the systems locale
 * into UTF-8 before using this function, see
 * stringprep_locale_to_utf8().
 *
 * Since the stringprep operation can expand the string, @maxlen
 * indicate how large the buffer holding the string is.  This function
 * will not read or write to characters outside that size.
 *
 * The @flags are one of #Stringprep_profile_flags values, or 0.
 *
 * The @profile contain the #Stringprep_profile instructions to
 * perform.  Your application can define new profiles, possibly
 * re-using the generic stringprep tables that always will be part of
 * the library, or use one of the currently supported profiles.
 *
 * Return value: Returns %STRINGPREP_OK iff successful, or an error code.
 **/
int
stringprep (char *in,
	    size_t maxlen,
	    Stringprep_profile_flags flags,
	    const Stringprep_profile * profile)
{
  int rc;
  char *utf8 = NULL;
  uint32_t *ucs4 = NULL;
  size_t ucs4len, maxucs4len, adducs4len = 50;

  do
    {
      uint32_t *newp;

      free (ucs4);
      ucs4 = stringprep_utf8_to_ucs4 (in, -1, &ucs4len);
      maxucs4len = ucs4len + adducs4len;
      newp = realloc (ucs4, maxucs4len * sizeof (uint32_t));
      if (!newp)
	{
	  free (ucs4);
	  return STRINGPREP_MALLOC_ERROR;
	}
      ucs4 = newp;

      rc = stringprep_4i (ucs4, &ucs4len, maxucs4len, flags, profile);
      adducs4len += 50;
    }
  while (rc == STRINGPREP_TOO_SMALL_BUFFER);
  if (rc != STRINGPREP_OK)
    {
      free (ucs4);
      return rc;
    }

  utf8 = stringprep_ucs4_to_utf8 (ucs4, ucs4len, 0, 0);
  free (ucs4);
  if (!utf8)
    return STRINGPREP_MALLOC_ERROR;

  if (strlen (utf8) >= maxlen)
    {
      free (utf8);
      return STRINGPREP_TOO_SMALL_BUFFER;
    }

  strcpy (in, utf8);		/* flawfinder: ignore */

  free (utf8);

  return STRINGPREP_OK;
}

/**
 * stringprep_profile:
 * @in: input array with UTF-8 string to prepare.
 * @out: output variable with pointer to newly allocate string.
 * @profile: name of stringprep profile to use.
 * @flags: a #Stringprep_profile_flags value, or 0.
 *
 * Prepare the input zero terminated UTF-8 string according to the
 * stringprep profile, and return the result in a newly allocated
 * variable.
 *
 * Note that you must convert strings entered in the systems locale
 * into UTF-8 before using this function, see
 * stringprep_locale_to_utf8().
 *
 * The output @out variable must be deallocated by the caller.
 *
 * The @flags are one of #Stringprep_profile_flags values, or 0.
 *
 * The @profile specifies the name of the stringprep profile to use.
 * It must be one of the internally supported stringprep profiles.
 *
 * Return value: Returns %STRINGPREP_OK iff successful, or an error code.
 **/
int
stringprep_profile (const char *in,
		    char **out,
		    const char *profile, Stringprep_profile_flags flags)
{
  const Stringprep_profiles *p;
  char *str = NULL;
  size_t len = strlen (in) + 1;
  int rc;

  for (p = &stringprep_profiles[0]; p->name; p++)
    if (strcmp (p->name, profile) == 0)
      break;

  if (!p || !p->name || !p->tables)
    return STRINGPREP_UNKNOWN_PROFILE;

  do
    {
      free (str);
      str = (char *) malloc (len);
      if (str == NULL)
	return STRINGPREP_MALLOC_ERROR;

      strcpy (str, in);

      rc = stringprep (str, len, flags, p->tables);
      len += 50;
    }
  while (rc == STRINGPREP_TOO_SMALL_BUFFER);

  if (rc == STRINGPREP_OK)
    *out = str;
  else
    free (str);

  return rc;
}

/*! \mainpage GNU Internationalized Domain Name Library
 *
 * \section intro Introduction
 *
 * GNU Libidn is an implementation of the Stringprep, Punycode and IDNA
 * specifications defined by the IETF Internationalized Domain Names
 * (IDN) working group, used for internationalized domain names.  The
 * package is available under the GNU Lesser General Public License.
 *
 * The library contains a generic Stringprep implementation that does
 * Unicode 3.2 NFKC normalization, mapping and prohibitation of
 * characters, and bidirectional character handling.  Profiles for
 * Nameprep, iSCSI, SASL and XMPP are included.  Punycode and ASCII
 * Compatible Encoding (ACE) via IDNA are supported.  A mechanism to
 * define Top-Level Domain (TLD) specific validation tables, and to
 * compare strings against those tables, is included.  Default tables
 * for some TLDs are also included.
 *
 * The Stringprep API consists of two main functions, one for
 * converting data from the system's native representation into UTF-8,
 * and one function to perform the Stringprep processing.  Adding a
 * new Stringprep profile for your application within the API is
 * straightforward.  The Punycode API consists of one encoding
 * function and one decoding function.  The IDNA API consists of the
 * ToASCII and ToUnicode functions, as well as an high-level interface
 * for converting entire domain names to and from the ACE encoded
 * form.  The TLD API consists of one set of functions to extract the
 * TLD name from a domain string, one set of functions to locate the
 * proper TLD table to use based on the TLD name, and core functions
 * to validate a string against a TLD table, and some utility wrappers
 * to perform all the steps in one call.
 *
 * The library is used by, e.g., GNU SASL and Shishi to process user
 * names and passwords.  Libidn can be built into GNU Libc to enable a
 * new system-wide getaddrinfo() flag for IDN processing.
 *
 * Libidn is developed for the GNU/Linux system, but runs on over 20 Unix
 * platforms (including Solaris, IRIX, AIX, and Tru64) and Windows.
 * Libidn is written in C and (parts of) the API is accessible from C,
 * C++, Emacs Lisp, Python and Java.
 *
 * The project web page:\n
 * http://www.gnu.org/software/libidn/
 *
 * The software archive:\n
 * ftp://alpha.gnu.org/pub/gnu/libidn/
 *
 * For more information see:\n
 * http://www.ietf.org/html.charters/idn-charter.html\n
 * http://www.ietf.org/rfc/rfc3454.txt (stringprep specification)\n
 * http://www.ietf.org/rfc/rfc3490.txt (idna specification)\n
 * http://www.ietf.org/rfc/rfc3491.txt (nameprep specification)\n
 * http://www.ietf.org/rfc/rfc3492.txt (punycode specification)\n
 * http://www.ietf.org/internet-drafts/draft-ietf-ips-iscsi-string-prep-04.txt\n
 * http://www.ietf.org/internet-drafts/draft-ietf-krb-wg-utf8-profile-01.txt\n
 * http://www.ietf.org/internet-drafts/draft-ietf-sasl-anon-00.txt\n
 * http://www.ietf.org/internet-drafts/draft-ietf-sasl-saslprep-00.txt\n
 * http://www.ietf.org/internet-drafts/draft-ietf-xmpp-nodeprep-01.txt\n
 * http://www.ietf.org/internet-drafts/draft-ietf-xmpp-resourceprep-01.txt\n
 *
 * Further information and paid contract development:\n
 * Simon Josefsson <simon@josefsson.org>
 *
 * \section examples Examples
 *
 * \include example.c
 * \include example3.c
 * \include example4.c
 * \include example5.c
 */

/**
 * STRINGPREP_VERSION
 *
 * String defined via CPP denoting the header file version number.
 * Used together with stringprep_check_version() to verify header file
 * and run-time library consistency.
 */

/**
 * STRINGPREP_MAX_MAP_CHARS
 *
 * Maximum number of code points that can replace a single code point,
 * during stringprep mapping.
 */

/**
 * Stringprep_rc:
 * @STRINGPREP_OK: Successful operation.  This value is guaranteed to
 *   always be zero, the remaining ones are only guaranteed to hold
 *   non-zero values, for logical comparison purposes.
 * @STRINGPREP_CONTAINS_UNASSIGNED: String contain unassigned Unicode
 *   code points, which is forbidden by the profile.
 * @STRINGPREP_CONTAINS_PROHIBITED: String contain code points
 *   prohibited by the profile.
 * @STRINGPREP_BIDI_BOTH_L_AND_RAL: String contain code points with
 *   conflicting bidirection category.
 * @STRINGPREP_BIDI_LEADTRAIL_NOT_RAL: Leading and trailing character
 *   in string not of proper bidirectional category.
 * @STRINGPREP_BIDI_CONTAINS_PROHIBITED: Contains prohibited code
 *   points detected by bidirectional code.
 * @STRINGPREP_TOO_SMALL_BUFFER: Buffer handed to function was too
 *   small.  This usually indicate a problem in the calling
 *   application.
 * @STRINGPREP_PROFILE_ERROR: The stringprep profile was inconsistent.
 *   This usually indicate an internal error in the library.
 * @STRINGPREP_FLAG_ERROR: The supplied flag conflicted with profile.
 *   This usually indicate a problem in the calling application.
 * @STRINGPREP_UNKNOWN_PROFILE: The supplied profile name was not
 *   known to the library.
 * @STRINGPREP_NFKC_FAILED: The Unicode NFKC operation failed.  This
 *   usually indicate an internal error in the library.
 * @STRINGPREP_MALLOC_ERROR: The malloc() was out of memory.  This is
 *   usually a fatal error.
 *
 * Enumerated return codes of stringprep(), stringprep_profile()
 * functions (and macros using those functions).  The value 0 is
 * guaranteed to always correspond to success.
 */

/**
 * Stringprep_profile_flags:
 * @STRINGPREP_NO_NFKC: Disable the NFKC normalization, as well as
 *   selecting the non-NFKC case folding tables.  Usually the profile
 *   specifies BIDI and NFKC settings, and applications should not
 *   override it unless in special situations.
 * @STRINGPREP_NO_BIDI: Disable the BIDI step.  Usually the profile
 *   specifies BIDI and NFKC settings, and applications should not
 *   override it unless in special situations.
 * @STRINGPREP_NO_UNASSIGNED: Make the library return with an error if
 *   string contains unassigned characters according to profile.
 *
 * Stringprep profile flags.
 */

/**
 * Stringprep_profile_steps:
 * @STRINGPREP_NFKC: The NFKC step.
 * @STRINGPREP_BIDI: The BIDI step.
 * @STRINGPREP_MAP_TABLE: The MAP step.
 * @STRINGPREP_UNASSIGNED_TABLE: The Unassigned step.
 * @STRINGPREP_PROHIBIT_TABLE: The Prohibited step.
 * @STRINGPREP_BIDI_PROHIBIT_TABLE: The BIDI-Prohibited step.
 * @STRINGPREP_BIDI_RAL_TABLE: The BIDI-RAL step.
 * @STRINGPREP_BIDI_L_TABLE: The BIDI-L step.
 *
 * Various steps in the stringprep algorithm.  You really want to
 * study the source code to understand this one.  Only useful if you
 * want to add another profile.
 */

/**
 * stringprep_nameprep:
 * @in: input/ouput array with string to prepare.
 * @maxlen: maximum length of input/output array.
 *
 * Prepare the input UTF-8 string according to the nameprep profile.
 * The AllowUnassigned flag is true, use
 * stringprep_nameprep_no_unassigned() if you want a false
 * AllowUnassigned.  Returns 0 iff successful, or an error code.
 **/

/**
 * stringprep_nameprep_no_unassigned:
 * @in: input/ouput array with string to prepare.
 * @maxlen: maximum length of input/output array.
 *
 * Prepare the input UTF-8 string according to the nameprep profile.
 * The AllowUnassigned flag is false, use stringprep_nameprep() for
 * true AllowUnassigned.  Returns 0 iff successful, or an error code.
 **/

/**
 * stringprep_iscsi:
 * @in: input/ouput array with string to prepare.
 * @maxlen: maximum length of input/output array.
 *
 * Prepare the input UTF-8 string according to the draft iSCSI
 * stringprep profile.  Returns 0 iff successful, or an error code.
 **/

/**
 * stringprep_plain:
 * @in: input/ouput array with string to prepare.
 * @maxlen: maximum length of input/output array.
 *
 * Prepare the input UTF-8 string according to the draft SASL
 * ANONYMOUS profile.  Returns 0 iff successful, or an error code.
 **/

/**
 * stringprep_xmpp_nodeprep:
 * @in: input/ouput array with string to prepare.
 * @maxlen: maximum length of input/output array.
 *
 * Prepare the input UTF-8 string according to the draft XMPP node
 * identifier profile.  Returns 0 iff successful, or an error code.
 **/

/**
 * stringprep_xmpp_resourceprep:
 * @in: input/ouput array with string to prepare.
 * @maxlen: maximum length of input/output array.
 *
 * Prepare the input UTF-8 string according to the draft XMPP resource
 * identifier profile.  Returns 0 iff successful, or an error code.
 **/
