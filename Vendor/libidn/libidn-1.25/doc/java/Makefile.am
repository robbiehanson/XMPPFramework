## Process this file with automake to produce Makefile.in
# Copyright (C) 2004-2012 Simon Josefsson
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

if JAVA
HTML = about.html deprecated.html package-list alphaindex.html		\
	index.html serialized-form.html					\
	resources/gjdochtml-clean-color1.css				\
	resources/gjdochtml-clean-layout.css resources/gjdoc.js		\
	resources/inherit.png gnu/inet/encoding/classes.html		\
	gnu/inet/encoding/CombiningClass.html				\
	gnu/inet/encoding/Composition.html				\
	gnu/inet/encoding/DecompositionKeys.html			\
	gnu/inet/encoding/DecompositionMappings.html			\
	gnu/inet/encoding/IDNAException.html				\
	gnu/inet/encoding/IDNA.html gnu/inet/encoding/NFKC.html		\
	gnu/inet/encoding/package-summary.html				\
	gnu/inet/encoding/PunycodeException.html			\
	gnu/inet/encoding/Punycode.html gnu/inet/encoding/RFC3454.html	\
	gnu/inet/encoding/StringprepException.html			\
	gnu/inet/encoding/Stringprep.html gnu/inet/encoding/tree.html
EXTRA_DIST = $(HTML)

all-local: $(HTML)

$(HTML): $(top_srcdir)/java/gnu/inet/encoding/*.java
	cd ../../java && make javadoc

clean-local:
	rm -f $(HTML)
endif
