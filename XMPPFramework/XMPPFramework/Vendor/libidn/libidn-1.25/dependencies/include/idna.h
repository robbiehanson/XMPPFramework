/* idna.h --- Prototypes for Internationalized Domain Name library.
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

#ifndef IDNA_H
# define IDNA_H

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

# include <stddef.h>		/* size_t */
# include <idn-int.h>		/* uint32_t */

# ifdef __cplusplus
extern "C"
{
# endif

  /* Error codes. */
  typedef enum
  {
    IDNA_SUCCESS = 0,
    IDNA_STRINGPREP_ERROR = 1,
    IDNA_PUNYCODE_ERROR = 2,
    IDNA_CONTAINS_NON_LDH = 3,
    /* Workaround typo in earlier versions. */
    IDNA_CONTAINS_LDH = IDNA_CONTAINS_NON_LDH,
    IDNA_CONTAINS_MINUS = 4,
    IDNA_INVALID_LENGTH = 5,
    IDNA_NO_ACE_PREFIX = 6,
    IDNA_ROUNDTRIP_VERIFY_ERROR = 7,
    IDNA_CONTAINS_ACE_PREFIX = 8,
    IDNA_ICONV_ERROR = 9,
    /* Internal errors. */
    IDNA_MALLOC_ERROR = 201,
    IDNA_DLOPEN_ERROR = 202
  } Idna_rc;

  /* IDNA flags */
  typedef enum
  {
    IDNA_ALLOW_UNASSIGNED = 0x0001,
    IDNA_USE_STD3_ASCII_RULES = 0x0002
  } Idna_flags;

# ifndef IDNA_ACE_PREFIX
#  define IDNA_ACE_PREFIX "xn--"
# endif

  extern IDNAPI const char *idna_strerror (Idna_rc rc);

  /* Core functions */
  extern IDNAPI int idna_to_ascii_4i (const uint32_t * in, size_t inlen,
				      char *out, int flags);
  extern IDNAPI int idna_to_unicode_44i (const uint32_t * in, size_t inlen,
					 uint32_t * out, size_t * outlen,
					 int flags);

  /* Wrappers that handle several labels */

  extern IDNAPI int idna_to_ascii_4z (const uint32_t * input,
				      char **output, int flags);

  extern IDNAPI int idna_to_ascii_8z (const char *input, char **output,
				      int flags);

  extern IDNAPI int idna_to_ascii_lz (const char *input, char **output,
				      int flags);

  extern IDNAPI int idna_to_unicode_4z4z (const uint32_t * input,
					  uint32_t ** output, int flags);

  extern IDNAPI int idna_to_unicode_8z4z (const char *input,
					  uint32_t ** output, int flags);

  extern IDNAPI int idna_to_unicode_8z8z (const char *input,
					  char **output, int flags);

  extern IDNAPI int idna_to_unicode_8zlz (const char *input,
					  char **output, int flags);

  extern IDNAPI int idna_to_unicode_lzlz (const char *input,
					  char **output, int flags);

# ifdef __cplusplus
}
# endif

#endif				/* IDNA_H */
