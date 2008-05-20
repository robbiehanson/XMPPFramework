/* toutf8.c	Convert strings from system locale into UTF-8.
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

#ifdef HAVE_ICONV

#include <iconv.h>

#if LOCALE_WORKS
#include <langinfo.h>
#include <locale.h>
#endif

static const char *
stringprep_locale_charset_slow (void)
{
  const char *charset = getenv ("CHARSET");	/* flawfinder: ignore */

  if (charset && *charset)
    return charset;

#if LOCALE_WORKS
  {
    char *p;

    p = setlocale (LC_CTYPE, NULL);
    setlocale (LC_CTYPE, "");

    charset = nl_langinfo (CODESET);

    setlocale (LC_CTYPE, p);

    if (charset && *charset)
      return charset;
  }
#endif

  return "ASCII";
}

static const char *stringprep_locale_charset_cache = NULL;

/**
 * stringprep_locale_charset:
 *
 * Find out system locale charset.
 *
 * Note that this function return what it believe the SYSTEM is using
 * as a locale, not what locale the program is currently in (modified,
 * e.g., by a setlocale(LC_CTYPE, "ISO-8859-1")).  The reason is that
 * data read from argv[], stdin etc comes from the system, and is more
 * likely to be encoded using the system locale than the program
 * locale.
 *
 * You can set the environment variable CHARSET to override the value
 * returned.  Note that this function caches the result, so you will
 * have to modify CHARSET before calling (even indirectly) any
 * stringprep functions, e.g., by setting it when invoking the
 * application.
 *
 * Return value: Return the character set used by the system locale.
 *   It will never return NULL, but use "ASCII" as a fallback.
 **/
const char *
stringprep_locale_charset (void)
{
  if (!stringprep_locale_charset_cache)
    stringprep_locale_charset_cache = stringprep_locale_charset_slow ();

  return stringprep_locale_charset_cache;
}

/**
 * stringprep_convert:
 * @str: input zero-terminated string.
 * @to_codeset: name of destination character set.
 * @from_codeset: name of origin character set, as used by @str.
 *
 * Convert the string from one character set to another using the
 * system's iconv() function.
 *
 * Return value: Returns newly allocated zero-terminated string which
 *   is @str transcoded into to_codeset.
 **/
char *
stringprep_convert (const char *str,
		    const char *to_codeset, const char *from_codeset)
{
  iconv_t cd;
  char *dest;
  char *outp;
  char *p, *startp;
  size_t inbytes_remaining;
  size_t outbytes_remaining;
  size_t err;
  size_t outbuf_size;
  int have_error = 0;
  int len;

  if (strcmp (to_codeset, from_codeset) == 0)
    return (char *) strdup (str);

  cd = iconv_open (to_codeset, from_codeset);

  if (cd == (iconv_t) - 1)
    return NULL;

  p = (char *) strdup (str);
  if (p == NULL)
    return NULL;
  len = strlen (p);
  startp = p;
  inbytes_remaining = len;
  outbuf_size = len + 1;	/* + 1 for nul in case len == 1 */

  outbytes_remaining = outbuf_size - 1;	/* -1 for nul */
  outp = dest = malloc (outbuf_size);

again:

  err = iconv (cd, (ICONV_CONST char **) &p, &inbytes_remaining,
	       &outp, &outbytes_remaining);

  if (err == (size_t) - 1)
    {
      switch (errno)
	{
	case EINVAL:
	  /* Incomplete text, do not report an error */
	  break;

	case E2BIG:
	  {
	    size_t used = outp - dest;

	    outbuf_size *= 2;
	    dest = realloc (dest, outbuf_size);

	    outp = dest + used;
	    outbytes_remaining = outbuf_size - used - 1;	/* -1 for nul */

	    goto again;
	  }
	  break;

	case EILSEQ:
	  have_error = 1;
	  break;

	default:
	  have_error = 1;
	  break;
	}
    }

  *outp = '\0';

  if ((p - startp) != len)
    have_error = 1;


  free (startp);

  iconv_close (cd);

  if (have_error)
    {
      free (dest);
      dest = NULL;
    }

  return dest;
}

#else

const char *
stringprep_locale_charset ()
{
  return "ASCII";
}

char *
stringprep_convert (const char *str,
		    const char *to_codeset, const char *from_codeset)
{
  fprintf (stderr, "libidn: warning: libiconv not installed, cannot "
	   "convert data to UTF-8\n");
  return strdup (str);
}

#endif

/**
 * stringprep_locale_to_utf8:
 * @str: input zero terminated string.
 *
 * Convert string encoded in the locale's character set into UTF-8 by
 * using stringprep_convert().
 *
 * Return value: Returns newly allocated zero-terminated string which
 *   is @str transcoded into UTF-8.
 **/
char *
stringprep_locale_to_utf8 (const char *str)
{
  return stringprep_convert (str, "UTF-8", stringprep_locale_charset ());
}

/**
 * stringprep_utf8_to_locale:
 * @str: input zero terminated string.
 *
 * Convert string encoded in UTF-8 into the locale's character set by
 * using stringprep_convert().
 *
 * Return value: Returns newly allocated zero-terminated string which
 *   is @str transcoded into the locale's character set.
 **/
char *
stringprep_utf8_to_locale (const char *str)
{
  return stringprep_convert (str, stringprep_locale_charset (), "UTF-8");
}
