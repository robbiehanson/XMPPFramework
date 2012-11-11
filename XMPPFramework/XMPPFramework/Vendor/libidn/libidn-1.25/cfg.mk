# Copyright (C) 2006-2012 Simon Josefsson
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

WFLAGS ?= --enable-gcc-warnings
ADDFLAGS ?=
CFGFLAGS ?= --enable-java --enable-gtk-doc --enable-gtk-doc-pdf \
	$(ADDFLAGS) $(WFLAGS)

ifeq ($(.DEFAULT_GOAL),abort-due-to-no-makefile)
.DEFAULT_GOAL := bootstrap
endif

local-checks-to-skip = sc_prohibit_strcmp sc_prohibit_have_config_h	\
	sc_require_config_h sc_require_config_h_first			\
	sc_prohibit_HAVE_MBRTOWC sc_program_name sc_trailing_blank	\
	sc_GPL_version sc_immutable_NEWS
VC_LIST_ALWAYS_EXCLUDE_REGEX = \
	^(GNUmakefile|maint.mk|gtk-doc.make|m4/pkg.m4|doc/specifications|contrib/doxygen/Doxyfile|doc/fdl-1.3.texi|csharp/libidn.*suo|(lib/)?(gl|gltests|build-aux)/)
update-copyright-env = UPDATE_COPYRIGHT_HOLDER="Simon Josefsson" UPDATE_COPYRIGHT_USE_INTERVALS=1

# Explicit syntax-check exceptions.
exclude_file_name_regexp--sc_bindtextdomain = ^examples/|libc/|tests/
exclude_file_name_regexp--sc_prohibit_atoi_atof = ^examples/example2.c$$
exclude_file_name_regexp--sc_copyright_check = ^doc/libidn.texi
exclude_file_name_regexp--sc_useless_cpp_parens = ^lib/nfkc.c$$

doc/Makefile.gdoc:
	printf "gdoc_MANS =\ngdoc_TEXINFOS =\n" > doc/Makefile.gdoc

autoreconf: doc/Makefile.gdoc
	for f in po/*.po.in; do \
		cp $$f `echo $$f | sed 's/.in//'`; \
	done
	mv build-aux/config.rpath build-aux/config.rpath-
	touch ChangeLog
	test -f ./configure || autoreconf --install
	mv build-aux/config.rpath- build-aux/config.rpath

update-po: refresh-po
	for f in `ls po/*.po | grep -v quot.po`; do \
		cp $$f $$f.in; \
	done
	git add po/*.po.in
	git commit -m "Sync with TP." po/LINGUAS po/*.po.in

bootstrap: autoreconf
	./configure $(CFGFLAGS)

review-diff:
	git diff `git describe --abbrev=0`.. \
	| grep -v -e ^index -e '^diff --git' \
	| filterdiff -p 1 -x 'build-aux/*' -x 'gl/*' -x 'gltests/*' -x 'lib/gl/*' -x 'lib/gltests/*' -x 'po/*' -x 'maint.mk' -x '.gitignore' -x '.x-sc*' -x ChangeLog -x GNUmakefile \
	| less

# Release

htmldir = ../www-$(PACKAGE)

i18n:
	-$(MAKE) update-po

coverage-my:
	ln -s . lib/gl/unistr/unistr
	ln -s . lib/gltests/glthread/glthread
	ln -s . lib/gltests/unistr/unistr
	$(MAKE) coverage WERROR_CFLAGS=

coverage-copy:
	rm -fv `find $(htmldir)/coverage -type f | grep -v CVS`
	cp -rv $(COVERAGE_OUT)/* $(htmldir)/coverage/

coverage-upload:
	cd $(htmldir) && cvs commit -m "Update." coverage

clang:
	make clean
	scan-build ./configure
	rm -rf scan.tmp
	scan-build -o scan.tmp make

clang-copy:
	rm -fv `find $(htmldir)/clang-analyzer -type f | grep -v CVS`
	mkdir -p $(htmldir)/clang-analyzer/
	cp -rv scan.tmp/*/* $(htmldir)/clang-analyzer/

clang-upload:
	cd $(htmldir) && \
		cvs add clang-analyzer || true && \
		cvs add clang-analyzer/*.css clang-analyzer/*.js \
			clang-analyzer/*.html || true && \
		cvs commit -m "Update." clang-analyzer

cyclo-copy:
	cp -v doc/cyclo/cyclo-$(PACKAGE).html $(htmldir)/cyclo/index.html

cyclo-upload:
	cd $(htmldir) && cvs commit -m "Update." cyclo/index.html

gendoc-copy:
	cd doc && env MAKEINFO="makeinfo -I ../examples" \
		      TEXI2DVI="texi2dvi -I ../examples" \
		$(SHELL) ../build-aux/gendocs.sh \
		--html "--css-include=texinfo.css" \
		-o ../$(htmldir)/manual/ $(PACKAGE) "$(PACKAGE_NAME)"

gendoc-upload:
	cd $(htmldir) && \
		cvs add manual || true && \
		cvs add manual/html_node || true && \
		cvs add -kb manual/*.gz manual/*.pdf || true && \
		cvs add manual/*.txt manual/*.html \
			manual/html_node/*.html || true && \
		cvs commit -m "Update." manual/

gtkdoc-copy:
	mkdir -p $(htmldir)/reference/
	cp -v doc/reference/$(PACKAGE).pdf \
		doc/reference/html/*.html \
		doc/reference/html/*.png \
		doc/reference/html/*.devhelp2 \
		doc/reference/html/*.css \
		$(htmldir)/reference/

gtkdoc-upload:
	cd $(htmldir) && \
		cvs add reference || true && \
		cvs add -kb reference/*.png reference/*.pdf || true && \
		cvs add reference/*.html reference/*.css \
			reference/*.devhelp2 || true && \
		cvs commit -m "Update." reference/

javadoc-copy:
	cp -rv doc/java/* $(htmldir)/javadoc/

javadoc-upload:
	cd $(htmldir) && \
		cvs commit -m "Update." javadoc/

doxygen-copy:
	cd contrib/doxygen && doxygen && cd ../.. && cp -v contrib/doxygen/html/* $(htmldir)/doxygen/ && cd contrib/doxygen/latex && make refman.pdf && cd ../../../ && cp contrib/doxygen/latex/refman.pdf $(htmldir)/doxygen/$(PACKAGE).pdf

doxygen-upload:
	cd $(htmldir) && \
		cvs commit -m "Update." doxygen/

ChangeLog:
	git2cl > ChangeLog
	cat .clcopying >> ChangeLog

tag = $(PACKAGE)-`echo $(VERSION) | sed 's/\./-/g'`

tarball:
	! git tag -l $(tag) | grep $(PACKAGE) > /dev/null
	rm -f ChangeLog
	$(MAKE) ChangeLog distcheck

binaries:
	cd win32 && make -f libidn4win.mk libidn4win VERSION=$(VERSION)

binaries-upload:
	cd win32 && make -f libidn4win.mk upload VERSION=$(VERSION)

source:
	git commit -m Generated. ChangeLog
	git tag -u b565716f! -m $(VERSION) $(tag)

release-check: syntax-check i18n tarball binaries gendoc-copy gtkdoc-copy coverage-my coverage-copy clang clang-copy cyclo-copy javadoc-copy doxygen-copy

release-upload-www: gendoc-upload gtkdoc-upload coverage-upload clang-upload cyclo-upload javadoc-upload doxygen-upload

release-upload-ftp:
	build-aux/gnupload --to ftp.gnu.org:$(PACKAGE) $(distdir).tar.gz
	cp $(distdir).tar.gz $(distdir).tar.gz.sig ../releases/$(PACKAGE)/
	git push
	git push --tags

release: release-check release-upload-www source release-upload-ftp binaries-upload
