/* tst_symbols.c --- Test if all exported symbols are available.
 * Copyright (C) 2010-2012 Simon Josefsson
 *
 * This file is part of GNU Libidn.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <assert.h>

#include <stringprep.h>
#include <idna.h>
#include <punycode.h>
#include <idn-free.h>
#include <pr29.h>
#ifdef WITH_TLD
# include <tld.h>
#endif

static void
assert_symbol_exists (const void *p)
{
  assert (p);
}

int
main (void)
{
  assert_symbol_exists ((const void *) idn_free);
  assert_symbol_exists ((const void *) idna_strerror);
  assert_symbol_exists ((const void *) idna_to_ascii_4i);
  assert_symbol_exists ((const void *) idna_to_ascii_4z);
  assert_symbol_exists ((const void *) idna_to_ascii_8z);
  assert_symbol_exists ((const void *) idna_to_ascii_lz);
  assert_symbol_exists ((const void *) idna_to_unicode_44i);
  assert_symbol_exists ((const void *) idna_to_unicode_4z4z);
  assert_symbol_exists ((const void *) idna_to_unicode_8z4z);
  assert_symbol_exists ((const void *) idna_to_unicode_8z8z);
  assert_symbol_exists ((const void *) idna_to_unicode_8zlz);
  assert_symbol_exists ((const void *) idna_to_unicode_lzlz);
  assert_symbol_exists ((const void *) pr29_4);
  assert_symbol_exists ((const void *) pr29_4z);
  assert_symbol_exists ((const void *) pr29_8z);
  assert_symbol_exists ((const void *) pr29_strerror);
  assert_symbol_exists ((const void *) punycode_decode);
  assert_symbol_exists ((const void *) punycode_encode);
  assert_symbol_exists ((const void *) punycode_strerror);
  assert_symbol_exists ((const void *) stringprep);
  assert_symbol_exists ((const void *) stringprep_4i);
  assert_symbol_exists ((const void *) stringprep_4zi);
  assert_symbol_exists ((const void *) stringprep_check_version);
  assert_symbol_exists ((const void *) stringprep_convert);
  assert_symbol_exists ((const void *) stringprep_iscsi);
  assert_symbol_exists ((const void *) stringprep_iscsi_prohibit);
  assert_symbol_exists ((const void *) stringprep_kerberos5);
  assert_symbol_exists ((const void *) stringprep_locale_charset);
  assert_symbol_exists ((const void *) stringprep_locale_to_utf8);
  assert_symbol_exists ((const void *) stringprep_nameprep);
  assert_symbol_exists ((const void *) stringprep_plain);
  assert_symbol_exists ((const void *) stringprep_profile);
  assert_symbol_exists ((const void *) stringprep_profiles);
  assert_symbol_exists ((const void *) stringprep_rfc3454_A_1);
  assert_symbol_exists ((const void *) stringprep_rfc3454_B_1);
  assert_symbol_exists ((const void *) stringprep_rfc3454_B_2);
  assert_symbol_exists ((const void *) stringprep_rfc3454_B_3);
  assert_symbol_exists ((const void *) stringprep_rfc3454_C_1_1);
  assert_symbol_exists ((const void *) stringprep_rfc3454_C_1_2);
  assert_symbol_exists ((const void *) stringprep_rfc3454_C_2_1);
  assert_symbol_exists ((const void *) stringprep_rfc3454_C_2_2);
  assert_symbol_exists ((const void *) stringprep_rfc3454_C_3);
  assert_symbol_exists ((const void *) stringprep_rfc3454_C_4);
  assert_symbol_exists ((const void *) stringprep_rfc3454_C_5);
  assert_symbol_exists ((const void *) stringprep_rfc3454_C_6);
  assert_symbol_exists ((const void *) stringprep_rfc3454_C_7);
  assert_symbol_exists ((const void *) stringprep_rfc3454_C_8);
  assert_symbol_exists ((const void *) stringprep_rfc3454_C_9);
  assert_symbol_exists ((const void *) stringprep_rfc3454_D_1);
  assert_symbol_exists ((const void *) stringprep_rfc3454_D_2);
  assert_symbol_exists ((const void *) stringprep_saslprep);
  assert_symbol_exists ((const void *) stringprep_saslprep_space_map);
  assert_symbol_exists ((const void *) stringprep_strerror);
  assert_symbol_exists ((const void *) stringprep_trace);
  assert_symbol_exists ((const void *) stringprep_ucs4_nfkc_normalize);
  assert_symbol_exists ((const void *) stringprep_ucs4_to_utf8);
  assert_symbol_exists ((const void *) stringprep_unichar_to_utf8);
  assert_symbol_exists ((const void *) stringprep_utf8_nfkc_normalize);
  assert_symbol_exists ((const void *) stringprep_utf8_to_locale);
  assert_symbol_exists ((const void *) stringprep_utf8_to_ucs4);
  assert_symbol_exists ((const void *) stringprep_utf8_to_unichar);
  assert_symbol_exists ((const void *) stringprep_xmpp_nodeprep);
  assert_symbol_exists ((const void *) stringprep_xmpp_nodeprep_prohibit);
  assert_symbol_exists ((const void *) stringprep_xmpp_resourceprep);
  assert_symbol_exists ((const void *) tld_check_4);
  assert_symbol_exists ((const void *) tld_check_4t);
  assert_symbol_exists ((const void *) tld_check_4tz);
  assert_symbol_exists ((const void *) tld_check_4z);
  assert_symbol_exists ((const void *) tld_check_8z);
  assert_symbol_exists ((const void *) tld_check_lz);
  assert_symbol_exists ((const void *) tld_default_table);
  assert_symbol_exists ((const void *) tld_get_4);
  assert_symbol_exists ((const void *) tld_get_4z);
  assert_symbol_exists ((const void *) tld_get_table);
  assert_symbol_exists ((const void *) tld_get_z);
  assert_symbol_exists ((const void *) tld_strerror);

  return 0;
}
