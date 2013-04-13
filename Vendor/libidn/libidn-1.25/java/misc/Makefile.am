## Process this file with automake to produce Makefile.in
# Copyright (C) 2004-2012  Free Software Foundation
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

JAVAROOT = $(top_builddir)/java/misc
AM_JAVACFLAGS = -classpath $(top_builddir)/java/libidn-$(VERSION).jar:$(top_srcdir)/java/libidn-$(VERSION).jar

if JAVA
dist_noinst_JAVA = \
	GenerateRFC3454.java \
	GenerateNFKC.java \
	TestIDNA.java \
	TestNFKC.java
endif
