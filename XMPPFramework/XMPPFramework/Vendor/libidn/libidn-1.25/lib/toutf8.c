/* toutf8.c --- Convert strings from system locale into UTF-8.
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

/* Get prototypes. */
#include "stringprep.h"

/* Get fprintf. */
#include <stdio.h>

/* Get getenv. */
#include <stdlib.h>

/* Get strlen. */
#include <string.h>

/* Get iconv_string. */
#include "striconv.h"

#ifdef _LIBC
# define HAVE_ICONV 1
# define HAVE_LOCALE_H 1
# define HAVE_LANGINFO_CODESET 1
#endif

#include <locale.h>

#ifdef HAVE_LANGINFO_CODESET
# include <langinfo.h>
#endif

#ifdef _LIBC
# define stringprep_locale_charset() nl_langinfo (CODESET)
#else
/**
 * stringprep_locale_charset:
 *
 * Find out current locale charset.  The function respect the CHARSET
 * environment variable, but typically uses nl_langinfo(CODESET) when
 * it is supported.  It fall back on "ASCII" if CHARSET isn't set and
 * nl_langinfo isn't supported or return anything.
 *
 * Note that this function return the application's locale's preferred
 * charset (or thread's locale's preffered charset, if your system
 * support thread-specific locales).  It does not return what the
 * system may be using.  Thus, if you receive data from external
 * sources you cannot in general use this function to guess what
 * charset it is encoded in.  Use stringprep_convert from the external
 * representation into the charset returned by this function, to have
 * data in the locale encoding.
 *
 * Return value: Return the character set used by the current locale.
 *   It will never return NULL, but use "ASCII" as a fallback.
 **/
const char *
stringprep_locale_charset (void)
{
  const char *charset = getenv ("CHARSET");	/* flawfinder: ignore */

  if (charset && *charset)
    return charset;

# ifdef HAVE_LANGINFO_CODESET
  charset = nl_langinfo (CODESET);

  if (charset && *charset)
    return charset;
# endif

  return "ASCII";
}
#endif

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
#if HAVE_ICONV
  return str_iconv (str, from_codeset, to_codeset);
#else
  char *p;
  fprintf (stderr, "libidn: warning: libiconv not installed, cannot "
	   "convert data to UTF-8\n");
  p = malloc (strlen (str) + 1);
  if (!p)
    return NULL;
  return strcpy (p, str);
#endif
}

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
