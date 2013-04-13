/* profiles.c --- Definitions of stringprep profiles.
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

#include <config.h>
#include "stringprep.h"

const Stringprep_profiles stringprep_profiles[] = {
  {"Nameprep", stringprep_nameprep},
  {"KRBprep", stringprep_kerberos5},	/* Deprecate? */
  {"Nodeprep", stringprep_xmpp_nodeprep},
  {"Resourceprep", stringprep_xmpp_resourceprep},
  {"plain", stringprep_plain},	/* sasl-anon-00. */
  {"trace", stringprep_trace},	/* sasl-anon-01,02,03. */
  {"SASLprep", stringprep_saslprep},
  {"ISCSIprep", stringprep_iscsi},	/* Obsolete. */
  {"iSCSI", stringprep_iscsi},	/* IANA. */
  {NULL, NULL}
};

const Stringprep_profile stringprep_nameprep[] = {
  {STRINGPREP_MAP_TABLE, 0, stringprep_rfc3454_B_1},
  {STRINGPREP_MAP_TABLE, 0, stringprep_rfc3454_B_2},
  {STRINGPREP_NFKC, 0, 0},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_1_2},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_2_2},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_3},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_4},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_5},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_6},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_7},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_8},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_9},
  {STRINGPREP_BIDI, 0, 0},
  {STRINGPREP_BIDI_PROHIBIT_TABLE, ~STRINGPREP_NO_BIDI,
   stringprep_rfc3454_C_8},
  {STRINGPREP_BIDI_RAL_TABLE, 0, stringprep_rfc3454_D_1},
  {STRINGPREP_BIDI_L_TABLE, 0, stringprep_rfc3454_D_2},
  {STRINGPREP_UNASSIGNED_TABLE, ~STRINGPREP_NO_UNASSIGNED,
   stringprep_rfc3454_A_1},
  {0}
};

const Stringprep_profile stringprep_kerberos5[] = {
  /* XXX this is likely to be wrong as the specification is
     a rough draft. */
  {STRINGPREP_MAP_TABLE, 0, stringprep_rfc3454_B_1},
  {STRINGPREP_MAP_TABLE, 0, stringprep_rfc3454_B_3},
  {STRINGPREP_NFKC, 0, 0},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_1_2},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_2_2},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_3},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_4},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_5},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_6},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_7},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_8},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_9},
  {STRINGPREP_BIDI, 0, 0},
  {STRINGPREP_BIDI_PROHIBIT_TABLE, ~STRINGPREP_NO_BIDI,
   stringprep_rfc3454_C_8},
  {STRINGPREP_BIDI_RAL_TABLE, 0, stringprep_rfc3454_D_1},
  {STRINGPREP_BIDI_L_TABLE, 0, stringprep_rfc3454_D_2},
  {STRINGPREP_UNASSIGNED_TABLE, ~STRINGPREP_NO_UNASSIGNED,
   stringprep_rfc3454_A_1},
  {0}
};

const Stringprep_table_element stringprep_xmpp_nodeprep_prohibit[] = {
  {0x000022},			/* #x22 (") */
  {0x000026},			/* #x26 (&) */
  {0x000027},			/* #x27 (') */
  {0x00002F},			/* #x2F (/) */
  {0x00003A},			/* #x3A (:) */
  {0x00003C},			/* #x3C (<) */
  {0x00003E},			/* #x3E (>) */
  {0x000040},			/* #x40 (@) */
  {0}
};

const Stringprep_profile stringprep_xmpp_nodeprep[] = {
  {STRINGPREP_MAP_TABLE, 0, stringprep_rfc3454_B_1},
  {STRINGPREP_MAP_TABLE, 0, stringprep_rfc3454_B_2},
  {STRINGPREP_NFKC, 0, 0},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_1_1},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_1_2},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_2_1},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_2_2},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_3},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_4},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_5},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_6},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_7},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_8},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_9},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_xmpp_nodeprep_prohibit},
  {STRINGPREP_BIDI, 0, 0},
  {STRINGPREP_BIDI_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_8},
  {STRINGPREP_BIDI_RAL_TABLE, 0, stringprep_rfc3454_D_1},
  {STRINGPREP_BIDI_L_TABLE, 0, stringprep_rfc3454_D_2},
  {STRINGPREP_UNASSIGNED_TABLE, ~STRINGPREP_NO_UNASSIGNED,
   stringprep_rfc3454_A_1},
  {0}
};

const Stringprep_profile stringprep_xmpp_resourceprep[] = {
  {STRINGPREP_MAP_TABLE, 0, stringprep_rfc3454_B_1},
  {STRINGPREP_NFKC, 0, 0},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_1_2},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_2_1},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_2_2},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_3},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_4},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_5},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_6},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_7},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_8},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_9},
  {STRINGPREP_BIDI, 0, 0},
  {STRINGPREP_BIDI_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_8},
  {STRINGPREP_BIDI_RAL_TABLE, ~STRINGPREP_NO_BIDI, stringprep_rfc3454_D_1},
  {STRINGPREP_BIDI_L_TABLE, ~STRINGPREP_NO_BIDI, stringprep_rfc3454_D_2},
  {STRINGPREP_UNASSIGNED_TABLE, ~STRINGPREP_NO_UNASSIGNED,
   stringprep_rfc3454_A_1},
  {0}
};

const Stringprep_profile stringprep_plain[] = {
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_2_1},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_2_2},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_3},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_4},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_5},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_6},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_8},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_9},
  {STRINGPREP_BIDI, 0, 0},
  {STRINGPREP_BIDI_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_8},
  {STRINGPREP_BIDI_RAL_TABLE, ~STRINGPREP_NO_BIDI, stringprep_rfc3454_D_1},
  {STRINGPREP_BIDI_L_TABLE, ~STRINGPREP_NO_BIDI, stringprep_rfc3454_D_2},
  {0}
};

const Stringprep_profile stringprep_trace[] = {
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_2_1},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_2_2},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_3},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_4},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_5},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_6},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_8},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_9},
  {STRINGPREP_BIDI, 0, 0},
  {STRINGPREP_BIDI_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_8},
  {STRINGPREP_BIDI_RAL_TABLE, ~STRINGPREP_NO_BIDI, stringprep_rfc3454_D_1},
  {STRINGPREP_BIDI_L_TABLE, ~STRINGPREP_NO_BIDI, stringprep_rfc3454_D_2},
  {0}
};

const Stringprep_table_element stringprep_iscsi_prohibit[] = {
  /* NB, since start == 0, we must have that end != 0 for the
     end-of-table logic to work. */
  {0x0000, 1},			/* [ASCII CONTROL CHARACTERS and SPACE through ,] */
  {0x0001},
  {0x0002},
  {0x0003},
  {0x0004},
  {0x0005},
  {0x0006},
  {0x0007},
  {0x0008},
  {0x0009},
  {0x000A},
  {0x000B},
  {0x000C},
  {0x000D},
  {0x000E},
  {0x000F},
  {0x0010},
  {0x0011},
  {0x0012},
  {0x0013},
  {0x0014},
  {0x0015},
  {0x0016},
  {0x0017},
  {0x0018},
  {0x0019},
  {0x001A},
  {0x001B},
  {0x001C},
  {0x001D},
  {0x001E},
  {0x001F},
  {0x0020},
  {0x0021},
  {0x0022},
  {0x0023},
  {0x0024},
  {0x0025},
  {0x0026},
  {0x0027},
  {0x0028},
  {0x0029},
  {0x002A},
  {0x002B},
  {0x002C},
  {0x002F},			/* [ASCII /] */
  {0x003B},			/* [ASCII ; through @] */
  {0x003C},
  {0x003D},
  {0x003E},
  {0x003F},
  {0x0040},
  {0x005B},			/* [ASCII [ through `] */
  {0x005C},
  {0x005D},
  {0x005E},
  {0x005F},
  {0x0060},
  {0x007B},			/* [ASCII { through DEL] */
  {0x007C},
  {0x007D},
  {0x007E},
  {0x007F},
  {0x3002},			/* ideographic full stop */
  {0}
};

const Stringprep_profile stringprep_iscsi[] = {
  {STRINGPREP_MAP_TABLE, 0, stringprep_rfc3454_B_1},
  {STRINGPREP_MAP_TABLE, 0, stringprep_rfc3454_B_2},
  {STRINGPREP_NFKC, 0, 0},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_1_1},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_1_2},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_2_1},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_2_2},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_3},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_4},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_5},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_6},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_7},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_8},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_9},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_iscsi_prohibit},
  {STRINGPREP_BIDI, 0, 0},
  {STRINGPREP_BIDI_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_8},
  {STRINGPREP_BIDI_RAL_TABLE, ~STRINGPREP_NO_BIDI, stringprep_rfc3454_D_1},
  {STRINGPREP_BIDI_L_TABLE, ~STRINGPREP_NO_BIDI, stringprep_rfc3454_D_2},
  {STRINGPREP_UNASSIGNED_TABLE, ~STRINGPREP_NO_UNASSIGNED,
   stringprep_rfc3454_A_1},
  {0}
};

const Stringprep_table_element stringprep_saslprep_space_map[] = {
  {0x0000A0, 0, {0x0020}},	/* 00A0; NO-BREAK SPACE */
  {0x001680, 0, {0x0020}},	/* 1680; OGHAM SPACE MARK */
  {0x002000, 0, {0x0020}},	/* 2000; EN QUAD */
  {0x002001, 0, {0x0020}},	/* 2001; EM QUAD */
  {0x002002, 0, {0x0020}},	/* 2002; EN SPACE */
  {0x002003, 0, {0x0020}},	/* 2003; EM SPACE */
  {0x002004, 0, {0x0020}},	/* 2004; THREE-PER-EM SPACE */
  {0x002005, 0, {0x0020}},	/* 2005; FOUR-PER-EM SPACE */
  {0x002006, 0, {0x0020}},	/* 2006; SIX-PER-EM SPACE */
  {0x002007, 0, {0x0020}},	/* 2007; FIGURE SPACE */
  {0x002008, 0, {0x0020}},	/* 2008; PUNCTUATION SPACE */
  {0x002009, 0, {0x0020}},	/* 2009; THIN SPACE */
  {0x00200A, 0, {0x0020}},	/* 200A; HAIR SPACE */
  {0x00200B, 0, {0x0020}},	/* 200B; ZERO WIDTH SPACE */
  {0x00202F, 0, {0x0020}},	/* 202F; NARROW NO-BREAK SPACE */
  {0x00205F, 0, {0x0020}},	/* 205F; MEDIUM MATHEMATICAL SPACE */
  {0x003000, 0, {0x0020}},	/* 3000; IDEOGRAPHIC SPACE */
  {0}
};

const Stringprep_profile stringprep_saslprep[] = {
  {STRINGPREP_MAP_TABLE, 0, stringprep_saslprep_space_map},
  {STRINGPREP_MAP_TABLE, 0, stringprep_rfc3454_B_1},
  {STRINGPREP_NFKC, 0, 0},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_1_2},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_2_1},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_2_2},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_3},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_4},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_5},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_6},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_7},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_8},
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_9},
  {STRINGPREP_BIDI, 0, 0},
  {STRINGPREP_BIDI_PROHIBIT_TABLE, 0, stringprep_rfc3454_C_8},
  {STRINGPREP_BIDI_RAL_TABLE, ~STRINGPREP_NO_BIDI, stringprep_rfc3454_D_1},
  {STRINGPREP_BIDI_L_TABLE, ~STRINGPREP_NO_BIDI, stringprep_rfc3454_D_2},
  {STRINGPREP_UNASSIGNED_TABLE, ~STRINGPREP_NO_UNASSIGNED,
   stringprep_rfc3454_A_1},
  {0}
};
