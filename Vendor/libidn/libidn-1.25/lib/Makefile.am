## Process this file with automake to produce Makefile.in
# Copyright (C) 2002-2012 Simon Josefsson.
# Copyright (C) 2004, 2010-2012 Free Software Foundation, Inc.
#
# This file is part of GNU Libidn.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

EXTRA_DIST = gen-stringprep-tables.pl gen-unicode-tables.pl gen-tld-tables.pl

AM_CPPFLAGS = -I$(srcdir)/gl -Igl -DLIBIDN_BUILDING
AM_CPPFLAGS += -DLOCALEDIR=\"$(localedir)\"
AM_CFLAGS = $(WERROR_CFLAGS) $(WSTACK_CFLAGS) $(WARN_CFLAGS)
AM_CFLAGS += $(CFLAG_VISIBILITY)

lib_LTLIBRARIES = libidn.la

idn_int = idn-int.h

BUILT_SOURCES = $(idn_int) gunibreak.h gunicomp.h gunidecomp.h rfc3454.c tlds.c
DISTCLEANFILES = $(idn_int)
include_HEADERS = stringprep.h idna.h punycode.h idn-free.h pr29.h
if TLD
include_HEADERS += tld.h
endif
nodist_include_HEADERS = $(idn_int)

idn-int.h:
	if test -n "$(STDINT_H)"; then \
		sed -e s/include_next/include/ gl/stdint.h > idn-int.h; \
	else \
		echo '#include <stdint.h>' > idn-int.h; \
	fi

libidn_la_SOURCES = libidn.map \
	gunibreak.h gunicomp.h gunidecomp.h \
	nfkc.c toutf8.c version.c \
	stringprep.h stringprep.c rfc3454.c profiles.c \
	punycode.h punycode.c \
	idna.h idna.c \
	pr29.h pr29.c \
	idn-free.h idn-free.c \
	strerror-idna.c strerror-pr29.c strerror-punycode.c \
	strerror-stringprep.c strerror-tld.c

if TLD
libidn_la_SOURCES += tld.h tld.c tlds.c
endif
libidn_la_LIBADD = $(LTLIBICONV) $(LTLIBINTL) gl/libgnu.la
libidn_la_LDFLAGS = \
	-version-info $(LT_CURRENT):$(LT_REVISION):$(LT_AGE) -no-undefined

if HAVE_LD_VERSION_SCRIPT
libidn_la_LDFLAGS += -Wl,--version-script=$(srcdir)/libidn.map
else
libidn_la_LDFLAGS += -export-symbols-regex \
			'^(idn|pr29_|punycode_|stringprep|tld_).*'
endif

if HAVE_LD_OUTPUT_DEF
libidn_la_LDFLAGS += -Wl,--output-def,libidn-$(DLL_VERSION).def
defexecdir = $(bindir)
defexec_DATA = libidn-$(DLL_VERSION).def
CLEANFILES = $(defexec_DATA)
libidn-$(DLL_VERSION).def: libidn.la
endif

SPEC = $(top_srcdir)/doc/specifications

#nfkc.c: gunibreak.h gunicomp.h gunidecomp.h
#gunibreak.h gunicomp.h gunidecomp.h: gen-unicode-tables.pl $(SPEC)/UnicodeData-3.2.0.txt $(SPEC)/LineBreak-3.2.0.txt $(SPEC)/SpecialCasing-3.2.0.txt $(SPEC)/CaseFolding-3.2.0.txt $(SPEC)/CompositionExclusions-3.2.0.txt
#	$(PERL) $(srcdir)/gen-unicode-tables.pl -decomp 3.2 $(SPEC)

rfc3454.c: gen-stringprep-tables.pl
	$(PERL) $(srcdir)/gen-stringprep-tables.pl $(SPEC)/rfc3454.txt

tlds.c: gen-tld-tables.pl
	$(PERL) $(srcdir)/gen-tld-tables.pl $(top_srcdir)/doc/tld/*.tld > tlds.c
