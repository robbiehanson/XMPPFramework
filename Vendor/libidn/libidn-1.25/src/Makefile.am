## Process this file with automake to produce Makefile.in
# Copyright (C) 2002-2012 Simon Josefsson
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

AM_CFLAGS = $(WERROR_CFLAGS) $(WARN_CFLAGS)
AM_CPPFLAGS = -I$(top_srcdir)/lib -I../lib -I$(top_srcdir)/gl -I../gl
AM_CPPFLAGS += -DLOCALEDIR=\"$(localedir)\"

dist_lisp_DATA = punycode.el idna.el

bin_PROGRAMS = idn
idn_SOURCES = idn.c
idn_LDADD = libidn_cmd.la ../lib/libidn.la ../gl/libgnu.la $(LTLIBINTL)

localedir = $(datadir)/locale

idn.c: $(BUILT_SOURCES)

noinst_LTLIBRARIES = libidn_cmd.la
libidn_cmd_la_SOURCES =  idn.ggo idn_cmd.c idn_cmd.h
libidn_cmd_la_LIBADD = ../gl/libgnu.la
libidn_cmd_la_CFLAGS =

idn_cmd.c idn_cmd.h: idn.ggo Makefile.am
	gengetopt --unamed-opts --no-handle-version --no-handle-help \
		--set-package="idn" \
		--input $^ --file-name idn_cmd
	perl -pi -e 's/\[OPTIONS\]/\[OPTION\]/g' idn_cmd.c
	perl -pi -e 's/\[FILES\]/\[STRING\]/g' idn_cmd.c

BUILT_SOURCES = idn_cmd.c idn_cmd.h
MAINTAINERCLEANFILES = $(BUILT_SOURCES)
