## Process this file with automake to produce Makefile.in
# Copyright (C) 2005-2012 Simon Josefsson.
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

CSHARPEXEC = $(SHELL) $(top_builddir)/csharpexec.sh
CSHARPCOMP = $(SHELL) $(top_builddir)/csharpcomp.sh
CSHARPCOMPFLAGS =

SOURCES = AssemblyInfo.cs IDNA.cs RFC3454.cs CombiningClass.cs	\
	IDNAException.cs Stringprep.cs Composition.cs NFKC.cs	\
	StringprepException.cs DecompositionKeys.cs Punycode.cs	\
	DecompositionMappings.cs PunycodeException.cs

SOURCES_GENERATE = generate/AssemblyInfo.cs \
	generate/GenerateNFKC.cs generate/GenerateRFC3454.cs \
	generate/HashSet.cs generate/Program.cs generate/Tokenizer.cs

MSVSC = libidn.csproj libidn.csproj.user libidn_PPC.csdproj	\
	libidn_PPC.csdproj.user libidn_PPC.sln libidn_PPC.suo	\
	libidn.sln libidn.suo

EXTRA_DIST = $(SOURCES) $(SOURCES_GENERATE) $(MSVSC)

CLEANFILES = Libidn.dll

ALL_LOCAL_TARGETS =
INSTALLDIRS_LOCAL_TARGETS = 
INSTALL_DATA_LOCAL_TARGETS =
UNINSTALL_LOCAL_TARGETS =

if CSHARP
ALL_LOCAL_TARGETS += Libidn.dll
INSTALLDIRS_LOCAL_TARGETS += install-dll-dir
INSTALL_DATA_LOCAL_TARGETS += install-dll
UNINSTALL_LOCAL_TARGETS += uninstall-dll

Libidn.dll: $(SOURCES)
	$(CSHARPCOMP) $(CSHARPCOMPFLAGS) -o $@ \
		`for src in $(SOURCES); do echo $(srcdir)/$$src; done`

SPEC = $(top_srcdir)/doc/specifications

GenerateTables.exe: $(SOURCES_GENERATE)
	$(CSHARPCOMP) $(CSHARPCOMPFLAGS) -o $@ \
		`for src in $(SOURCES_GENERATE); do echo $(srcdir)/$$src; done`
	if ! test -f rfc3454.txt; then \
		ln -s $(SPEC)/rfc3454.txt . \
		|| cp $(SPEC)/rfc3454.txt .; \
	fi
	if ! test -f UnicodeData.txt; then \
		ln -s $(SPEC)/UnicodeData-3.2.0.txt UnicodeData.txt \
		|| cp $(SPEC)/UnicodeData-3.2.0.txt UnicodeData.txt; \
	fi
	if ! test -f CompositionExclusions.txt; then \
		ln -s $(SPEC)/CompositionExclusions-3.2.0.txt CompositionExclusions.txt \
		|| cp $(SPEC)/CompositionExclusions-3.2.0.txt CompositionExclusions.txt; \
	fi

RFC3454.cs CombiningClass.cs DecompositionKeys.cs DecompositionMappings.cs Composition.cs: $(GEN_SOURCES)
	make GenerateTables.exe
	$(CSHARPEXEC) ./GenerateTables.exe

install-dll-dir:
	$(mkinstalldirs) $(DESTDIR)$(libdir)

install-dll: install-dll-dir
	$(INSTALL_DATA) Libidn.dll $(DESTDIR)$(libdir)/Libidn.dll

uninstall-dll:
	rm -f $(DESTDIR)$(libdir)/Libidn.dll
endif

all-local: $(ALL_LOCAL_TARGETS)
install-data-local: $(INSTALL_DATA_LOCAL_TARGETS)
installdirs-local: $(INSTALLDIRS_LOCAL_TARGETS)
uninstall-local: $(UNINSTALL_LOCAL_TARGETS)
