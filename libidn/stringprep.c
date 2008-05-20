/* stringprep.c		Core stringprep implementation.
 * Copyright (C) 2002, 2003  Simon Josefsson
 *
 * This file is part of GNU Libidn.
 *
 * GNU Libidn is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * GNU Libidn is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with GNU Libidn; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 */

#include "internal.h"

static ssize_t
stringprep_find_character_in_table (uint32_t ucs4,
				    Stringprep_table_element * table)
{
  ssize_t i;

  for (i = 0; table[i].start; i++)
    if (ucs4 >= table[i].start &&
	ucs4 <= (table[i].end ? table[i].end : table[i].start))
      return i;

  return -1;
}

static ssize_t
stringprep_find_string_in_table (uint32_t * ucs4,
				 size_t ucs4len,
				 size_t * tablepos,
				 Stringprep_table_element * table)
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

static enum Stringprep_rc
stringprep_apply_table_to_string (uint32_t * ucs4,
				  size_t * ucs4len,
				  size_t maxucs4len,
				  Stringprep_table_element * table,
				  const char *tablename)
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
	       *ucs4len * sizeof (uint32_t) - (&ucs4[pos + 1] - ucs4));
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
 * stringprep:
 * @in: input/ouput array with string to prepare.
 * @maxlen: maximum length of input/output array.
 * @flags: optional stringprep profile flags.
 * @profile: pointer to stringprep profile to use.
 *
 * Prepare the input UTF-8 string according to the stringprep profile.
 * Normally application programmers use stringprep profile macros such
 * as stringprep_nameprep(), stringprep_kerberos5() etc instead of
 * calling this function directly.
 *
 * Since the stringprep operation can expand the string, @maxlen
 * indicate how large the buffer holding the string is.  The @flags
 * are one of Stringprep_profile_flags, or 0.  The profile indicates
 * processing details specific to that profile.  Your application can
 * define new profiles, possibly re-using the generic stringprep
 * tables that always will be part of the library.
 *
 * Note that you must convert strings entered in the systems locale
 * into UTF-8 before using this function.
 *
 * Return value: Returns 0 iff successful, or an error code.
 **/
enum Stringprep_rc
stringprep (char *in,
	    size_t maxlen,
	    enum Stringprep_profile_flags flags, Stringprep_profile * profile)
{
  size_t i, j;
  ssize_t k;
  int rc;
  char *p = 0;
  uint32_t *q = 0;
  uint32_t *ucs4;
  size_t ucs4len, maxucs4len;

  ucs4 = stringprep_utf8_to_ucs4 (in, -1, &ucs4len);
  maxucs4len = 4 * ucs4len + 10;	/* XXX */
  ucs4 = realloc (ucs4, 1 + maxucs4len * sizeof (uint32_t));
  if (!ucs4)
    {
      rc = STRINGPREP_MALLOC_ERROR;
      goto done;
    }

  for (i = 0; profile[i].operation; i++)
    {
      switch (profile[i].operation)
	{
	case STRINGPREP_NFKC:
	  if (UNAPPLICAPLEFLAGS (flags, profile[i].flags))
	    {
	      break;
	    }

	  if (flags & STRINGPREP_NO_NFKC && !profile[i].flags)
	    {
	      /* Profile requires NFKC, but callee asked for no NFKC. */
	      rc = STRINGPREP_FLAG_ERROR;
	      goto done;
	    }

	  q = stringprep_ucs4_nfkc_normalize (ucs4, ucs4len);

	  if (!q)
	    {
	      rc = STRINGPREP_NFKC_FAILED;
	      goto done;
	    }

	  for (j = 0; q[j]; j++)
	    ;

	  free (ucs4);
	  ucs4 = q;
	  ucs4len = j;
	  q = 0;
	  break;

	case STRINGPREP_PROHIBIT_TABLE:
	  k = stringprep_find_string_in_table (ucs4, ucs4len,
					       NULL, profile[i].table);
	  if (k != -1)
	    {
	      rc = STRINGPREP_CONTAINS_PROHIBITED;
	      goto done;
	    }
	  break;

	case STRINGPREP_UNASSIGNED_TABLE:
	  if (UNAPPLICAPLEFLAGS (flags, profile[i].flags))
	    break;
	  if (flags & STRINGPREP_NO_UNASSIGNED)
	    {
	      k = stringprep_find_string_in_table
		(ucs4, ucs4len, NULL, profile[i].table);
	      if (k != -1)
		{
		  rc = STRINGPREP_CONTAINS_UNASSIGNED;
		  goto done;
		}
	    }
	  break;

	case STRINGPREP_MAP_TABLE:
	  if (UNAPPLICAPLEFLAGS (flags, profile[i].flags))
	    break;
	  rc = stringprep_apply_table_to_string
	    (ucs4, &ucs4len, maxucs4len, profile[i].table, profile[i].name);
	  if (rc != STRINGPREP_OK)
	    goto done;
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
	    int contains_ral = -1;
	    int contains_l = -1;

	    for (j = 0; profile[j].operation; j++)
	      if (profile[j].operation == STRINGPREP_BIDI_PROHIBIT_TABLE)
		{
		  done_prohibited = 1;
		  k = stringprep_find_string_in_table (ucs4, ucs4len,
						       NULL,
						       profile[j].table);
		  if (k != -1)
		    {
		      rc = STRINGPREP_BIDI_CONTAINS_PROHIBITED;
		      goto done;
		    }
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
	      {
		rc = STRINGPREP_PROFILE_ERROR;
		goto done;
	      }

	    if (contains_ral != -1 && contains_l != -1)
	      {
		rc = STRINGPREP_BIDI_BOTH_L_AND_RAL;
		goto done;
	      }

	    if (contains_ral != -1)
	      {
		if (!(stringprep_find_character_in_table
		      (ucs4[0], profile[contains_ral].table) != -1 &&
		      stringprep_find_character_in_table
		      (ucs4[ucs4len - 1], profile[contains_ral].table) != -1))
		  {
		    rc = STRINGPREP_BIDI_LEADTRAIL_NOT_RAL;
		    goto done;
		  }
	      }
	  }
	  break;

	default:
	  rc = STRINGPREP_PROFILE_ERROR;
	  goto done;
	  break;
	}
    }

  p = stringprep_ucs4_to_utf8 (ucs4, ucs4len, 0, 0);

  if (strlen (p) >= maxlen)
    {
      rc = STRINGPREP_TOO_SMALL_BUFFER;
      goto done;
    }

  strcpy (in, p);		/* flawfinder: ignore */

  rc = STRINGPREP_OK;

done:
  if (p)
    free (p);
  if (q)
    free (q);
  if (ucs4)
    free (ucs4);
  return rc;
}

/**
 * stringprep_profile:
 * @in: input/ouput array with string to prepare.
 * @out: output variable with newly allocate string.
 * @flags: optional stringprep profile flags.
 * @profile: name of stringprep profile to use.
 *
 * Prepare the input UTF-8 string according to the stringprep profile.
 * Normally application programmers use stringprep profile macros such
 * as stringprep_nameprep(), stringprep_kerberos5() etc instead of
 * calling this function directly.
 *
 * Note that you must convert strings entered in the systems locale
 * into UTF-8 before using this function.
 *
 * The output @out variable must be deallocated by the caller.
 *
 * Return value: Returns 0 iff successful, or an error code.
 **/
enum Stringprep_rc
stringprep_profile (char *in,
		    char **out,
		    char *profile, enum Stringprep_profile_flags flags)
{
  Stringprep_profiles *p;
  char *str;
  size_t len;
  int rc;

  for (p = &stringprep_profiles[0]; p->name; p++)
    if (strcmp (p->name, profile) == 0)
      break;

  if (!p || !p->name || !p->tables)
    return STRINGPREP_UNKNOWN_PROFILE;

  len = strlen (in) + BUFSIZ;
  str = (char *) malloc (len);
  if (str == NULL)
    return STRINGPREP_MALLOC_ERROR;

  strcpy (str, in);

  rc = stringprep (str, len, flags, p->tables);

  if (rc == STRINGPREP_OK)
    *out = str;
  else
    free (str);

  return rc;
}
