/* tld.h --- Declarations for TLD restriction checking.
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

#ifndef TLD_H
# define TLD_H

# ifndef IDNAPI
#  if defined LIBIDN_BUILDING && defined HAVE_VISIBILITY && HAVE_VISIBILITY
#   define IDNAPI __attribute__((__visibility__("default")))
#  elif defined LIBIDN_BUILDING && defined _MSC_VER && ! defined LIBIDN_STATIC
#   define IDNAPI __declspec(dllexport)
#  elif defined _MSC_VER && ! defined LIBIDN_STATIC
#   define IDNAPI __declspec(dllimport)
#  else
#   define IDNAPI
#  endif
# endif

# ifdef __cplusplus
extern "C"
{
# endif

  /* Get size_t. */
# include <stdlib.h>

  /* Get uint32_t. */
# include <idn-int.h>

  /* Interval of valid code points in the TLD. */
  struct Tld_table_element
  {
    uint32_t start;		/* Start of range. */
    uint32_t end;		/* End of range, end == start if single. */
  };
  typedef struct Tld_table_element Tld_table_element;

  /* List valid code points in a TLD. */
  struct Tld_table
  {
    const char *name;		/* TLD name, e.g., "no". */
    const char *version;	/* Version string from TLD file. */
    size_t nvalid;		/* Number of entries in data. */
    const Tld_table_element *valid;	/* Sorted array of valid code points. */
  };
  typedef struct Tld_table Tld_table;

  /* Error codes. */
  typedef enum
  {
    TLD_SUCCESS = 0,
    TLD_INVALID = 1,		/* Invalid character found. */
    TLD_NODATA = 2,		/* Char, domain or inlen = 0. */
    TLD_MALLOC_ERROR = 3,
    TLD_ICONV_ERROR = 4,
    TLD_NO_TLD = 5,
    /* Workaround typo in earlier versions. */
    TLD_NOTLD = TLD_NO_TLD
  } Tld_rc;

  extern IDNAPI const char *tld_strerror (Tld_rc rc);

  /* Extract TLD, as ASCII string, of UCS4 domain name into "out". */
  extern IDNAPI int tld_get_4 (const uint32_t * in, size_t inlen,
			       char **out);
  extern IDNAPI int tld_get_4z (const uint32_t * in, char **out);
  extern IDNAPI int tld_get_z (const char *in, char **out);

  /* Return structure corresponding to the named TLD from specified
   * list of TLD tables, or return NULL if no matching TLD can be
   * found. */
  extern IDNAPI const Tld_table *tld_get_table (const char *tld,
						const Tld_table ** tables);

  /* Return structure corresponding to the named TLD, first looking
   * thru overrides then thru built-in list, or return NULL if no
   * matching TLD can be found. */
  extern IDNAPI const Tld_table * tld_default_table (const char *tld,
						 const Tld_table ** overrides);

  /* Check NAMEPREPPED domain name for valid characters as defined by
   * the relevant registering body (plus [a-z0-9.-]).  If error is
   * TLD_INVALID, set errpos to position of offending character. */
  extern IDNAPI int tld_check_4t (const uint32_t * in, size_t inlen,
				  size_t * errpos, const Tld_table * tld);
  extern IDNAPI int tld_check_4tz (const uint32_t * in, size_t * errpos,
				   const Tld_table * tld);

  /* Utility interfaces that uses tld_get_4* to find TLD of string,
     then tld_default_table (with overrides) to find proper TLD table
     for the string, and then hands over to tld_check_4t*. */
  extern IDNAPI int tld_check_4 (const uint32_t * in, size_t inlen,
				 size_t * errpos,
				 const Tld_table ** overrides);
  extern IDNAPI int tld_check_4z (const uint32_t * in, size_t * errpos,
				  const Tld_table ** overrides);
  extern IDNAPI int tld_check_8z (const char *in, size_t * errpos,
				  const Tld_table ** overrides);
  extern IDNAPI int tld_check_lz (const char *in, size_t * errpos,
				  const Tld_table ** overrides);

# ifdef __cplusplus
}
# endif

#endif /* TLD_H */
