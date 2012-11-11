## Process this file with automake to produce Makefile.in
# Copyright (C) 2002-2012 Simon Josefsson.
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

SUBDIRS = specifications tld java cyclo
if ENABLE_GTK_DOC
SUBDIRS += . reference
endif

EXTRA_DIST = gdoc libidn.html libidn.ps libidn.pdf texinfo.css	\
	components.fig

info_TEXINFOS = libidn.texi
libidn_TEXINFOS = fdl-1.3.texi
libidn_TEXINFOS += $(gdoc_TEXINFOS)
libidn_TEXINFOS += libidn-components.eps libidn-components.png	\
			libidn-components.pdf

imagesdir = $(infodir)
images_DATA = libidn-components.png

libidn-components.eps: components.fig
	fig2dev -L eps $< $@

libidn-components.png: components.fig
	fig2dev -L png $< $@

libidn-components.pdf: components.fig
	fig2dev -L pdf $< $@

AM_MAKEINFOFLAGS = -I $(top_builddir)/doc -I $(top_srcdir)/examples
TEXI2DVI = texi2dvi $(AM_MAKEINFOFLAGS)
AM_MAKEINFOHTMLFLAGS = $(AM_MAKEINFOFLAGS) \
	--no-split --number-sections --css-include=texinfo.css

# Man pages.

dist_man_MANS = idn.1 $(gdoc_MANS)
MAINTAINERCLEANFILES = $(dist_man_MANS)

idn.1: $(top_srcdir)/src/idn.c $(top_srcdir)/src/idn.ggo \
		$(top_srcdir)/configure.ac
	$(HELP2MAN) \
		--name="Internationalized Domain Names command line tool" \
		--output=$@ $(top_builddir)/src/idn$(EXEEXT)

# GDOC

GDOC_SRC = $(top_srcdir)/lib/idna.c $(top_srcdir)/lib/nfkc.c	\
	$(top_srcdir)/lib/pr29.c $(top_srcdir)/lib/punycode.c	\
	$(top_srcdir)/lib/stringprep.c $(top_srcdir)/lib/tld.c	\
	$(top_srcdir)/lib/toutf8.c $(top_srcdir)/lib/version.c \
	$(top_srcdir)/lib/idn-free.c \
	$(top_srcdir)/lib/strerror-idna.c $(top_srcdir)/lib/strerror-pr29.c \
	$(top_srcdir)/lib/strerror-punycode.c \
	$(top_srcdir)/lib/strerror-stringprep.c \
	$(top_srcdir)/lib/strerror-tld.c
GDOC_TEXI_PREFIX = texi/
GDOC_MAN_PREFIX = man/
GDOC_MAN_EXTRA_ARGS = -module $(PACKAGE) -sourceversion $(VERSION) \
	-bugsto $(PACKAGE_BUGREPORT) -pkg-name "$(PACKAGE_NAME)" \
	-includefuncprefix -seeinfo $(PACKAGE) \
	-copyright "2002-2012 Simon Josefsson" \
	-verbatimcopying
include $(srcdir)/Makefile.gdoci
