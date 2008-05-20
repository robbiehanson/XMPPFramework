/* profiles.c	Definitions of stringprep profiles.
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

Stringprep_profiles stringprep_profiles[] = {
  {"generic", stringprep_generic}
  ,
  {"Nameprep", stringprep_nameprep}
  ,
  {"KRBprep", stringprep_kerberos5}
  ,
  {"Nodeprep", stringprep_xmpp_nodeprep}
  ,
  {"Resourceprep", stringprep_xmpp_resourceprep}
  ,
  {"plain", stringprep_plain}
  ,
  {"SASLprep", stringprep_saslprep}
  ,
  {"ISCSIprep", stringprep_iscsi}
  ,
  {NULL, NULL}
};

Stringprep_profile stringprep_generic[] = {
  /* 1) Map -- For each character in the input, check if it has a
     mapping and, if so, replace it with its mapping. This is
     described in section 3. */

  {STRINGPREP_MAP_TABLE, 0, stringprep_generic_B_1, "B.1"}
  ,
  {STRINGPREP_MAP_TABLE, ~STRINGPREP_NO_NFKC, stringprep_generic_B_2, "B.2"}
  ,
  {STRINGPREP_MAP_TABLE, STRINGPREP_NO_NFKC, stringprep_generic_B_3, "B.3"}
  ,

  /* 2) Normalize -- Possibly normalize the result of step 1 using
     Unicode normalization. This is described in section 4. */

  {STRINGPREP_NFKC, ~STRINGPREP_NO_NFKC, 0, "NFKC"}
  ,

  /* 3) Prohibit -- Check for any characters that are not allowed in
     the output. If any are found, return an error. This is
     described in section 5. */

  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_1_1, "C.1.1"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_1_2, "C.1.2"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_2_1, "C.2.1"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_2_2, "C.2.2"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_3, "C.3"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_4, "C.4"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_5, "C.5"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_6, "C.6"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_7, "C.7"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_8, "C.8"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_9, "C.9"}
  ,

  /* 4) Check bidi -- Possibly check for right-to-left characters, and
     if any are found, make sure that the whole string satisfies
     the requirements for bidirectional strings. If the string does
     not satisfy the requirements for bidirectional strings, return
     an error. This is described in section 6. */

  {STRINGPREP_BIDI, ~STRINGPREP_NO_BIDI, 0, "BIDI"}
  ,
  {STRINGPREP_BIDI_PROHIBIT_TABLE, ~STRINGPREP_NO_BIDI,
   stringprep_generic_C_8, "C.8"}
  ,
  {STRINGPREP_BIDI_RAL_TABLE, ~STRINGPREP_NO_BIDI, stringprep_generic_D_1,
   "D.1"}
  ,
  {STRINGPREP_BIDI_L_TABLE, ~STRINGPREP_NO_BIDI, stringprep_generic_D_2,
   "D.2"}
  ,

  /* 5) Check unassigned code points -- Possibly check the output for
     unassigned code points, according to the profile.  This is
     described in section 7. */

  {STRINGPREP_UNASSIGNED_TABLE, ~STRINGPREP_NO_UNASSIGNED,
   stringprep_generic_A_1, "A.1"}
  ,

  {0, 0, NULL, NULL}
};

Stringprep_profile stringprep_nameprep[] = {
  {STRINGPREP_MAP_TABLE, 0, stringprep_generic_B_1, "B.1"}
  ,
  {STRINGPREP_MAP_TABLE, 0, stringprep_generic_B_2, "B.2"}
  ,
  {STRINGPREP_NFKC, 0, 0, "NFKC"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_1_2, "C.1.2"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_2_2, "C.2.2"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_3, "C.3"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_4, "C.4"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_5, "C.5"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_6, "C.6"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_7, "C.7"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_8, "C.8"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_9, "C.9"}
  ,
  {STRINGPREP_BIDI, 0, 0, "BIDI"}
  ,
  {STRINGPREP_BIDI_PROHIBIT_TABLE, ~STRINGPREP_NO_BIDI,
   stringprep_generic_C_8, "C.8"}
  ,
  {STRINGPREP_BIDI_RAL_TABLE, 0, stringprep_generic_D_1, "D.1"}
  ,
  {STRINGPREP_BIDI_L_TABLE, 0, stringprep_generic_D_2, "D.2"}
  ,
  {STRINGPREP_UNASSIGNED_TABLE, ~STRINGPREP_NO_UNASSIGNED,
   stringprep_generic_A_1, "A.1"}
  ,
  {0, 0, NULL, NULL}
};

Stringprep_profile stringprep_kerberos5[] = {
  /* XXX this is likely to be wrong as the specification is
     a rough draft. */
  {STRINGPREP_MAP_TABLE, 0, stringprep_generic_B_1, "B.1"}
  ,
  {STRINGPREP_MAP_TABLE, 0, stringprep_generic_B_3, "B.2"}
  ,
  {STRINGPREP_NFKC, 0, 0, "NFKC"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_1_2, "C.1.2"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_2_2, "C.2.2"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_3, "C.3"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_4, "C.4"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_5, "C.5"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_6, "C.6"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_7, "C.7"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_8, "C.8"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_9, "C.9"}
  ,
  {STRINGPREP_BIDI, 0, 0, "BIDI"}
  ,
  {STRINGPREP_BIDI_PROHIBIT_TABLE, ~STRINGPREP_NO_BIDI,
   stringprep_generic_C_8, "C.8"}
  ,
  {STRINGPREP_BIDI_RAL_TABLE, 0, stringprep_generic_D_1, "D.1"}
  ,
  {STRINGPREP_BIDI_L_TABLE, 0, stringprep_generic_D_2, "D.2"}
  ,
  {STRINGPREP_UNASSIGNED_TABLE, ~STRINGPREP_NO_UNASSIGNED,
   stringprep_generic_A_1, "A.1"}
  ,
  {0, 0, NULL, NULL}
};

Stringprep_table_element stringprep_xmpp_nodeprep_prohibit[] = {
	{0x000022, 0, {0}}
  ,				/* #x22 (") */
	{0x000026, 0, {0}}
  ,				/* #x26 (&) */
	{0x000027, 0, {0}}
  ,				/* #x27 (') */
	{0x00002F, 0, {0}}
  ,				/* #x2F (/) */
	{0x00003A, 0, {0}}
  ,				/* #x3A (:) */
	{0x00003C, 0, {0}}
  ,				/* #x3C (<) */
	{0x00003E, 0, {0}}
  ,				/* #x3E (>) */
	{0x000040, 0, {0}}			/* #x40 (@) */
  ,
  {0, 0, {0}}
};

Stringprep_profile stringprep_xmpp_nodeprep[] = {
  {STRINGPREP_MAP_TABLE, 0, stringprep_generic_B_1, "B.1"}
  ,
  {STRINGPREP_MAP_TABLE, 0, stringprep_generic_B_2, "B.2"}
  ,
  {STRINGPREP_NFKC, 0, 0, "NFKC"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_1_1, "C.1.1"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_1_2, "C.1.2"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_2_1, "C.2.1"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_2_2, "C.2.2"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_3, "C.3"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_4, "C.4"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_5, "C.5"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_6, "C.6"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_7, "C.7"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_8, "C.8"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_9, "C.9"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_xmpp_nodeprep_prohibit,
   "XMPP-PROHIBIT"}
  ,
  {STRINGPREP_BIDI, 0, 0, "BIDI"}
  ,
  {STRINGPREP_BIDI_PROHIBIT_TABLE, 0, stringprep_generic_C_8, "C.8"}
  ,
  {STRINGPREP_BIDI_RAL_TABLE, 0, stringprep_generic_D_1, "D.1"}
  ,
  {STRINGPREP_BIDI_L_TABLE, 0, stringprep_generic_D_2, "D.2"}
  ,
  {STRINGPREP_UNASSIGNED_TABLE, ~STRINGPREP_NO_UNASSIGNED,
   stringprep_generic_A_1, "A.1"}
  ,
  {0, 0, NULL, NULL}
};

Stringprep_profile stringprep_xmpp_resourceprep[] = {
  {STRINGPREP_MAP_TABLE, 0, stringprep_generic_B_1, "B.1"}
  ,
  {STRINGPREP_NFKC, 0, 0, "NFKC"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_1_2, "C.1.2"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_2_1, "C.2.1"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_2_2, "C.2.2"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_3, "C.3"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_4, "C.4"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_5, "C.5"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_6, "C.6"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_7, "C.7"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_8, "C.8"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_9, "C.9"}
  ,
  {STRINGPREP_BIDI, 0, 0, "BIDI"}
  ,
  {STRINGPREP_BIDI_PROHIBIT_TABLE, 0, stringprep_generic_C_8, "C.8"}
  ,
  {STRINGPREP_BIDI_RAL_TABLE, ~STRINGPREP_NO_BIDI, stringprep_generic_D_1,
   "D.1"}
  ,
  {STRINGPREP_BIDI_L_TABLE, ~STRINGPREP_NO_BIDI, stringprep_generic_D_2,
   "D.2"}
  ,
  {STRINGPREP_UNASSIGNED_TABLE, ~STRINGPREP_NO_UNASSIGNED,
   stringprep_generic_A_1, "A.1"}
  ,
  {0, 0, NULL, NULL}
};

Stringprep_profile stringprep_plain[] = {
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_2_1, "C.2.1"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_2_2, "C.2.2"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_3, "C.3"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_4, "C.4"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_5, "C.5"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_6, "C.6"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_8, "C.8"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_9, "C.9"}
  ,
  {STRINGPREP_BIDI, 0, 0, "BIDI"}
  ,
  {STRINGPREP_BIDI_PROHIBIT_TABLE, 0, stringprep_generic_C_8, "C.8"}
  ,
  {STRINGPREP_BIDI_RAL_TABLE, ~STRINGPREP_NO_BIDI, stringprep_generic_D_1,
   "D.1"}
  ,
  {STRINGPREP_BIDI_L_TABLE, ~STRINGPREP_NO_BIDI, stringprep_generic_D_2,
   "D.2"}
  ,
	{0, 0, NULL, NULL}
};

Stringprep_table_element stringprep_iscsi_prohibit[] = {
	{0x0000, 0, {0}}
  ,				/* [ASCII CONTROL CHARACTERS and SPACE through ,] */
	{0x0001, 0, {0}}
  ,
	{0x0002, 0, {0}}
  ,
	{0x0003, 0, {0}}
  ,
	{0x0004, 0, {0}}
  ,
	{0x0005, 0, {0}}
  ,
	{0x0006, 0, {0}}
  ,
	{0x0007, 0, {0}}
  ,
	{0x0008, 0, {0}}
  ,
	{0x0009, 0, {0}}
  ,
	{0x000A, 0, {0}}
  ,
	{0x000B, 0, {0}}
  ,
	{0x000C, 0, {0}}
  ,
	{0x000D, 0, {0}}
  ,
	{0x000E, 0, {0}}
  ,
	{0x000F, 0, {0}}
  ,
	{0x0010, 0, {0}}
  ,
	{0x0011, 0, {0}}
  ,
	{0x0012, 0, {0}}
  ,
	{0x0013, 0, {0}}
  ,
	{0x0014, 0, {0}}
  ,
	{0x0015, 0, {0}}
  ,
	{0x0016, 0, {0}}
  ,
	{0x0017, 0, {0}}
  ,
	{0x0018, 0, {0}}
  ,
	{0x0019, 0, {0}}
  ,
	{0x001A, 0, {0}}
  ,
	{0x001B, 0, {0}}
  ,
	{0x001C, 0, {0}}
  ,
	{0x001D, 0, {0}}
  ,
	{0x001E, 0, {0}}
  ,
	{0x001F, 0, {0}}
  ,
	{0x0020, 0, {0}}
  ,
	{0x0021, 0, {0}}
  ,
	{0x0022, 0, {0}}
  ,
	{0x0023, 0, {0}}
  ,
	{0x0024, 0, {0}}
  ,
	{0x0025, 0, {0}}
  ,
	{0x0026, 0, {0}}
  ,
	{0x0027, 0, {0}}
  ,
	{0x0028, 0, {0}}
  ,
	{0x0029, 0, {0}}
  ,
	{0x002A, 0, {0}}
  ,
	{0x002B, 0, {0}}
  ,
	{0x002C, 0, {0}}
  ,
	{0x002F, 0, {0}}
  ,				/* [ASCII /] */
	{0x003B, 0, {0}}
  ,				/* [ASCII ; through @] */
	{0x003C, 0, {0}}
  ,
	{0x003D, 0, {0}}
  ,
	{0x003E, 0, {0}}
  ,
	{0x003F, 0, {0}}
  ,
	{0x0040, 0, {0}}
  ,
	{0x005B, 0, {0}}
  ,				/* [ASCII [ through `] */
	{0x005C, 0, {0}}
  ,
	{0x005D, 0, {0}}
  ,
	{0x005E, 0, {0}}
  ,
	{0x005F, 0, {0}}
  ,
	{0x0060, 0, {0}}
  ,
	{0x007B, 0, {0}}
  ,				/* [ASCII { through DEL] */
	{0x007C, 0, {0}}
  ,
	{0x007D, 0, {0}}
  ,
	{0x007E, 0, {0}}
  ,
	{0x007F, 0, {0}}
  ,
	{0x3002, 0, {0}}
  ,				/* ideographic full stop */
	{0, 0, {0}}
};

Stringprep_profile stringprep_iscsi[] = {
  {STRINGPREP_MAP_TABLE, 0, stringprep_generic_B_1, "B.1"}
  ,
  {STRINGPREP_MAP_TABLE, 0, stringprep_generic_B_2, "B.2"}
  ,
  {STRINGPREP_NFKC, 0, 0, "NFKC"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_2_1, "C.1.1"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_2_2, "C.1.2"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_2_1, "C.2.1"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_2_2, "C.2.2"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_3, "C.3"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_4, "C.4"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_5, "C.5"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_6, "C.6"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_8, "C.8"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_9, "C.9"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_iscsi_prohibit, "ISCSI-PROHIBIT"}
  ,
  {STRINGPREP_BIDI, 0, 0, "BIDI"}
  ,
  {STRINGPREP_BIDI_PROHIBIT_TABLE, 0, stringprep_generic_C_8, "C.8"}
  ,
  {STRINGPREP_BIDI_RAL_TABLE, ~STRINGPREP_NO_BIDI, stringprep_generic_D_1,
   "D.1"}
  ,
  {STRINGPREP_BIDI_L_TABLE, ~STRINGPREP_NO_BIDI, stringprep_generic_D_2,
   "D.2"}
  ,
  {STRINGPREP_UNASSIGNED_TABLE, ~STRINGPREP_NO_UNASSIGNED,
   stringprep_generic_A_1, "A.1"}
  ,
  {0, 0, NULL, NULL}
};

Stringprep_table_element stringprep_saslprep_space_map[] = {
  {0x0000A0, 0, {0x0020}
   }
  ,				/* 00A0; NO-BREAK SPACE */
  {0x001680, 0, {0x0020}
   }
  ,				/* 1680; OGHAM SPACE MARK */
  {0x002000, 0, {0x0020}
   }
  ,				/* 2000; EN QUAD */
  {0x002001, 0, {0x0020}
   }
  ,				/* 2001; EM QUAD */
  {0x002002, 0, {0x0020}
   }
  ,				/* 2002; EN SPACE */
  {0x002003, 0, {0x0020}
   }
  ,				/* 2003; EM SPACE */
  {0x002004, 0, {0x0020}
   }
  ,				/* 2004; THREE-PER-EM SPACE */
  {0x002005, 0, {0x0020}
   }
  ,				/* 2005; FOUR-PER-EM SPACE */
  {0x002006, 0, {0x0020}
   }
  ,				/* 2006; SIX-PER-EM SPACE */
  {0x002007, 0, {0x0020}
   }
  ,				/* 2007; FIGURE SPACE */
  {0x002008, 0, {0x0020}
   }
  ,				/* 2008; PUNCTUATION SPACE */
  {0x002009, 0, {0x0020}
   }
  ,				/* 2009; THIN SPACE */
  {0x00200A, 0, {0x0020}
   }
  ,				/* 200A; HAIR SPACE */
  {0x00200B, 0, {0x0020}
   }
  ,				/* 200B; ZERO WIDTH SPACE */
  {0x00202F, 0, {0x0020}
   }
  ,				/* 202F; NARROW NO-BREAK SPACE */
  {0x00205F, 0, {0x0020}
   }
  ,				/* 205F; MEDIUM MATHEMATICAL SPACE */
  {0x003000, 0, {0x0020}
   }
  ,				/* 3000; IDEOGRAPHIC SPACE */
	{0, 0, {0}}
};

Stringprep_profile stringprep_saslprep[] = {
  {STRINGPREP_MAP_TABLE, 0, stringprep_saslprep_space_map, "SASL-SPACE-MAP"}
  ,
  {STRINGPREP_MAP_TABLE, 0, stringprep_generic_B_1, "B.1"}
  ,
  {STRINGPREP_NFKC, 0, 0, "NFKC"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_2_2, "C.1.2"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_2_1, "C.2.1"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_2_2, "C.2.2"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_3, "C.3"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_4, "C.4"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_5, "C.5"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_6, "C.6"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_8, "C.8"}
  ,
  {STRINGPREP_PROHIBIT_TABLE, 0, stringprep_generic_C_9, "C.9"}
  ,
  {STRINGPREP_BIDI, 0, 0, "BIDI"}
  ,
  {STRINGPREP_BIDI_PROHIBIT_TABLE, 0, stringprep_generic_C_8, "C.8"}
  ,
  {STRINGPREP_BIDI_RAL_TABLE, ~STRINGPREP_NO_BIDI, stringprep_generic_D_1,
   "D.1"}
  ,
  {STRINGPREP_BIDI_L_TABLE, ~STRINGPREP_NO_BIDI, stringprep_generic_D_2,
   "D.2"}
  ,
  {STRINGPREP_UNASSIGNED_TABLE, ~STRINGPREP_NO_UNASSIGNED,
   stringprep_generic_A_1, "A.1"}
  ,
  {0, 0, NULL, NULL}
};
