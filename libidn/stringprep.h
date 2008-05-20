/* stringprep.h		Header file for stringprep functions.         -*- c -*-
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

#ifndef _STRINGPREP_H
#define _STRINGPREP_H

#ifdef __cplusplus
extern "C"
{
#endif

#include <stddef.h>		/* size_t */
#include <unistd.h>		/* ssize_t */
#include <stdint.h>             /* uint32_t */

#define STRINGPREP_VERSION "0.2.3"

/* Error codes. */
  enum Stringprep_rc
  {
    STRINGPREP_OK = 0,
    /* Stringprep errors. */
    STRINGPREP_CONTAINS_UNASSIGNED = 1,
    STRINGPREP_CONTAINS_PROHIBITED = 2,
    STRINGPREP_BIDI_BOTH_L_AND_RAL = 3,
    STRINGPREP_BIDI_LEADTRAIL_NOT_RAL = 4,
    STRINGPREP_BIDI_CONTAINS_PROHIBITED = 5,
    /* Error in calling application. */
    STRINGPREP_TOO_SMALL_BUFFER = 100,
    STRINGPREP_PROFILE_ERROR = 101,
    STRINGPREP_FLAG_ERROR = 102,
    STRINGPREP_UNKNOWN_PROFILE = 103,
    /* Internal errors. */
    STRINGPREP_NFKC_FAILED = 200,
    STRINGPREP_MALLOC_ERROR = 201
  };

/* Flags used when calling stringprep(). */
  enum Stringprep_profile_flags
  {
    STRINGPREP_NO_NFKC = 1,
    STRINGPREP_NO_BIDI = 2,
    STRINGPREP_NO_UNASSIGNED = 4
  };

/* Steps in a stringprep profile. */
  enum Stringprep_profile_steps
  {
    STRINGPREP_NFKC = 1,
    STRINGPREP_BIDI = 2,
    STRINGPREP_MAP_TABLE = 3,
    STRINGPREP_UNASSIGNED_TABLE = 4,
    STRINGPREP_PROHIBIT_TABLE = 5,
    STRINGPREP_BIDI_PROHIBIT_TABLE = 6,
    STRINGPREP_BIDI_RAL_TABLE = 7,
    STRINGPREP_BIDI_L_TABLE = 8
  };

#define STRINGPREP_MAX_MAP_CHARS 4

  struct Stringprep_table_element
  {
    uint32_t start;
    uint32_t end;		/* 0 if only one character */
    uint32_t map[STRINGPREP_MAX_MAP_CHARS];	/* NULL if end is not 0 */
  };
  typedef struct Stringprep_table_element Stringprep_table_element;

  struct Stringprep_table
  {
    enum Stringprep_profile_steps operation;
    enum Stringprep_profile_flags flags;
    Stringprep_table_element *table;
    const char *name;
  };
  typedef struct Stringprep_table Stringprep_profile;

  struct Stringprep_profiles
  {
    const char *name;
    Stringprep_profile *tables;
  };
  typedef struct Stringprep_profiles Stringprep_profiles;

  extern Stringprep_profiles stringprep_profiles[];

/* Profiles */
  extern Stringprep_table_element stringprep_generic_A_1[];
  extern Stringprep_table_element stringprep_generic_B_1[];
  extern Stringprep_table_element stringprep_generic_B_2[];
  extern Stringprep_table_element stringprep_generic_B_3[];
  extern Stringprep_table_element stringprep_generic_C_1_1[];
  extern Stringprep_table_element stringprep_generic_C_1_2[];
  extern Stringprep_table_element stringprep_generic_C_2_1[];
  extern Stringprep_table_element stringprep_generic_C_2_2[];
  extern Stringprep_table_element stringprep_generic_C_3[];
  extern Stringprep_table_element stringprep_generic_C_4[];
  extern Stringprep_table_element stringprep_generic_C_5[];
  extern Stringprep_table_element stringprep_generic_C_6[];
  extern Stringprep_table_element stringprep_generic_C_7[];
  extern Stringprep_table_element stringprep_generic_C_8[];
  extern Stringprep_table_element stringprep_generic_C_9[];
  extern Stringprep_table_element stringprep_generic_D_1[];
  extern Stringprep_table_element stringprep_generic_D_2[];

  /* Generic (for debugging) */

  extern Stringprep_profile stringprep_generic[];

#define stringprep_generic(in, maxlen)		\
  stringprep(in, maxlen, 0, stringprep_generic)

  /* Nameprep */

  extern Stringprep_profile stringprep_nameprep[];

#define stringprep_nameprep(in, maxlen)			\
  stringprep(in, maxlen, 0, stringprep_nameprep)

#define stringprep_nameprep_no_unassigned(in, maxlen)			\
  stringprep(in, maxlen, STRINGPREP_NO_UNASSIGNED, stringprep_nameprep)

  /* SASL */

  extern Stringprep_profile stringprep_saslprep[];
  extern Stringprep_profile stringprep_plain[];

#define stringprep_plain(in, maxlen)		\
  stringprep(in, maxlen, 0, stringprep_plain)

  /* Kerberos */

  extern Stringprep_profile stringprep_kerberos5[];

#define stringprep_kerberos5(in, maxlen)		\
  stringprep(in, maxlen, 0, stringprep_kerberos5)

  /* XMPP */

  extern Stringprep_profile stringprep_xmpp_nodeprep[];
  extern Stringprep_profile stringprep_xmpp_resourceprep[];
  extern Stringprep_table_element stringprep_xmpp_nodeprep_prohibit[];

#define stringprep_xmpp_nodeprep(in, maxlen)		\
  stringprep(in, maxlen, 0, stringprep_xmpp_nodeprep)
#define stringprep_xmpp_resourceprep(in, maxlen)		\
  stringprep(in, maxlen, 0, stringprep_xmpp_resourceprep)

  /* iSCSI */

  extern Stringprep_profile stringprep_iscsi[];

#define stringprep_iscsi(in, maxlen)		\
  stringprep(in, maxlen, 0, stringprep_iscsi)

  /* API */

  extern enum Stringprep_rc
    stringprep (char *in, size_t maxlen,
		enum Stringprep_profile_flags flags,
		Stringprep_profile *profile);

  extern enum Stringprep_rc
    stringprep_profile (char *in,
			char **out,
			char *profile, enum Stringprep_profile_flags flags);

  extern const char *stringprep_check_version (const char *req_version);

/* Utility */

  extern int stringprep_unichar_to_utf8 (uint32_t c, char *outbuf);
  extern uint32_t stringprep_utf8_to_unichar (const char *p);

  extern uint32_t *stringprep_utf8_to_ucs4 (const char *str, ssize_t len,
					    size_t * items_written);
  extern char *stringprep_ucs4_to_utf8 (const uint32_t * str, ssize_t len,
					size_t * items_read,
					size_t * items_written);

  extern char *stringprep_utf8_nfkc_normalize (const char *str, ssize_t len);
  extern uint32_t *stringprep_ucs4_nfkc_normalize (uint32_t * str,
						   ssize_t len);

  extern const char *stringprep_locale_charset (void);
  extern char *stringprep_convert (const char *str,
				   const char *to_codeset,
				   const char *from_codeset);
  extern char *stringprep_locale_to_utf8 (const char *str);
  extern char *stringprep_utf8_to_locale (const char *str);

#ifdef __cplusplus
}
#endif
#endif				/* _STRINGPREP_H */
