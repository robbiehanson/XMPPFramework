# Copyright (C) 2011-2012 Simon Josefsson
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

PACKAGE = libidn
distdir = $(PACKAGE)-$(VERSION)
TGZ = $(distdir).tar.gz
URL = ftp://ftp.gnu.org/gnu/$(PACKAGE)/$(TGZ)

all:
	@echo 'Usage examples:'
	@echo '  make -f libidn4win.mk libidn4win VERSION=1.21'
	@echo '  make -f libidn4win.mk libidn4win32 VERSION=1.21 CHECK=check'

libidn4win: libidn4win32 libidn4win64

libidn4win32:
	$(MAKE) -f libidn4win.mk doit ARCH=32 HOST=i686-w64-mingw32 CHECK=check

libidn4win64:
	$(MAKE) -f libidn4win.mk doit ARCH=64 HOST=x86_64-w64-mingw32

doit:
	rm -rf tmp$(ARCH) && mkdir tmp$(ARCH) && cd tmp$(ARCH) && \
	cp ../../libiconv-1.13.1.tar.gz . || wget ftp://ftp.gnu.org/gnu/libiconv/libiconv-1.13.1.tar.gz && \
	tar xfa libiconv-1.13.1.tar.gz && \
	cd libiconv-1.13.1 && \
	./configure --host=$(HOST) --build=x86_64-unknown-linux-gnu --prefix=$(PWD)/tmp$(ARCH)/root && \
	make install && \
	cd .. && \
	cp ../../$(TGZ) . || wget $(URL) && \
	tar xfa $(TGZ) && \
	cd $(distdir) && \
	./configure --host=$(HOST) --build=x86_64-unknown-linux-gnu --prefix=$(PWD)/tmp$(ARCH)/root CPPFLAGS=-I$(PWD)/tmp$(ARCH)/root/include && \
	make install && \
	make -C tests $(CHECK) && \
	cd .. && \
	cd root && \
	zip -r ../../$(distdir)-win$(ARCH).zip *

upload:
	../build-aux/gnupload --to ftp.gnu.org:$(PACKAGE) $(distdir)-win32.zip $(distdir)-win64.zip
	cp $(distdir)-win32.zip $(distdir)-win32.zip.sig $(distdir)-win64.zip $(distdir)-win64.zip.sig ../../releases/$(PACKAGE)/
