# PG'OCaml - type safe interface to PostgreSQL.
# Copyright (C) 2005-2009 Richard Jones and other authors.
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Library General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Library General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this library; see the file COPYING.  If not, write to
# the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA.

include Makefile.config

SED	:= sed
FGREP	:= fgrep

OCAMLCFLAGS	:= -g
OCAMLCPACKAGES	:= -package unix,extlib,pcre,calendar,csv
OCAMLCLIBS	:= -linkpkg

OCAMLOPTFLAGS	:=
OCAMLOPTPACKAGES := $(OCAMLCPACKAGES)
OCAMLOPTLIBS	:= -linkpkg

OCAMLDOCFLAGS := -html -stars -sort $(OCAMLCPACKAGES)

GETLIB=-I +$(1) $(shell ocamlfind query $(1) -predicates byte -format "%d/%a")

FOR_P4	:= \
	$(call GETLIB,unix) \
	$(call GETLIB,str) \
	$(call GETLIB,pcre) \
	$(call GETLIB,extlib) \
	$(call GETLIB,calendar) \
	$(call GETLIB,csv) \
	./pgocaml.cma

#
# This is split into two because back-tick notation
# doesn't necessarily work under Windows
#

OCAMLVERSION := $(shell ocamlc -v | $(FGREP) "version" | $(SED) -e "s/.*3\.\(..\)\..*/\1/")
P4_PARAMS := $(shell [ $(OCAMLVERSION) -ge 9 ] && echo -loc loc)

ifdef WINDOWS
  EXECUTABLE_SUFFIX := .exe
endif

#
# Top-rules.
#

OBJS	:= pGOCaml_config.cmo pGOCaml.cmo
XOBJS	:= $(OBJS:.cmo=.cmx)

all: META pGOCaml_config.ml pgocaml.cma pgocaml.cmxa pa_pgsql.cmo pgocaml_prof$(EXECUTABLE_SUFFIX)

test: test_pgocaml_lowlevel$(EXECUTABLE_SUFFIX) test_pgocaml$(EXECUTABLE_SUFFIX)

#
# Rules for testing programs.
#

test_pgocaml_lowlevel$(EXECUTABLE_SUFFIX): test_pgocaml_lowlevel.cmo pgocaml.cma
	ocamlfind ocamlc $(OCAMLCFLAGS) $(OCAMLCPACKAGES) $(OCAMLCLIBS) pgocaml.cma -o $@ $<

test_pgocaml$(EXECUTABLE_SUFFIX): test_pgocaml.cmo pgocaml.cma
	ocamlfind ocamlc $(OCAMLCFLAGS) $(OCAMLCPACKAGES) $(OCAMLCLIBS) pgocaml.cma -o $@ $<

pgocaml_prof$(EXECUTABLE_SUFFIX): pgocaml_prof.cmx
	ocamlfind ocamlopt $(OCAMLOPTFLAGS) $(OCAMLOPTPACKAGES) $(OCAMLOPTLIBS) -o $@ $<

test_pgocaml.cmo: test_pgocaml.ml pgocaml.cma pa_pgsql.cmo
	ocamlfind ocamlc $(OCAMLCFLAGS) $(OCAMLCPACKAGES) $(OCAMLCLIBS) -pp "camlp4o $(FOR_P4) ./pa_pgsql.cmo" -c $<

print_test: force
	camlp4o $(FOR_P4) ./pa_pgsql.cmo pr_o.cmo test_pgocaml.ml

#
# Rules for core library.
#

pa_pgsql.cmo: pa_pgsql.ml4
	ocamlfind ocamlc $(OCAMLCFLAGS) $(OCAMLCPACKAGES) \
	  -pp "camlp4o pa_extend.cmo q_MLast.cmo $(P4_PARAMS) -impl" \
	  -I +camlp4 -c -impl $<

pgocaml.cma: $(OBJS)
	ocamlfind ocamlc $(OCAMLCFLAGS) $(OCAMLCPACKAGES) -a -o $@ $^

pgocaml.cmxa: $(XOBJS)
	ocamlfind ocamlopt $(OCAMLOPTFLAGS) $(OCAMLOPTPACKAGES) -a -o $@ $^

pGOCaml_config.ml: pGOCaml_config.ml.in Makefile Makefile.config
	< $< sed -e "s|@DEFAULT_UNIX_DOMAIN_SOCKET_DIR@|$(DEFAULT_UNIX_DOMAIN_SOCKET_DIR)|" > $@

#
# Common rules for building OCaml objects.
#

.mli.cmi:
	ocamlfind ocamlc $(OCAMLCFLAGS) $(OCAMLCINCS) $(OCAMLCPACKAGES) -c $<
.ml.cmo:
	ocamlfind ocamlc $(OCAMLCFLAGS) $(OCAMLCINCS) $(OCAMLCPACKAGES) -c $<
.ml.cmx:
	ocamlfind ocamlopt $(OCAMLOPTFLAGS) $(OCAMLOPTINCS) $(OCAMLOPTPACKAGES) -c $<

#
# Findlib META file.
#

META:	META.in Makefile.config
	$(SED)  -e 's/@PACKAGE@/$(PACKAGE)/' \
		-e 's/@VERSION@/$(VERSION)/' \
		< $< > $@

#
# Clean.
#

clean:
	rm -f *.cmi *.cmo *.cmx *.cma *.cmxa *.o *.a *.so *~ core .depend META \
	test_pgocaml_lowlevel test_pgocaml pgocaml_prof

#
# Dependencies.
#

depend: .depend

.depend: pGOCaml_config.ml
	rm -f .depend
	ocamldep pGOCaml.mli pGOCaml.ml test_pgocaml_lowlevel.ml > $@
	-ocamldep -pp "camlp4o $(FOR_P4) ./pa_pgsql.cmo" test_pgocaml.ml >> $@

ifeq ($(wildcard .depend),.depend)
include .depend
endif

#
# Install.
#

findlib_install:
	ocamlfind install $(PACKAGE) META pgocaml.a pgocaml.cma pgocaml.cmxa pGOCaml.cm[ix] pa_pgsql.cmo pGOCaml.mli

reinstall:
	ocamlfind remove $(PACKAGE)
	ocamlfind install $(PACKAGE) META pgocaml.a pgocaml.cma pgocaml.cmxa pGOCaml.cm[ix] pa_pgsql.cmo pGOCaml.mli

install:
	rm -rf $(DESTDIR)$(OCAMLLIBDIR)/$(PACKAGE)
	install -c -m 0755 -d $(DESTDIR)$(OCAMLLIBDIR)/$(PACKAGE)
	install -c -m 0644 *.cmi *.mli *.cmo *.cma *.cmxa *.a META \
	  $(DESTDIR)$(OCAMLLIBDIR)/$(PACKAGE)

#
# Distribution.
#

dist:
	$(MAKE) check-manifest
	rm -rf $(PACKAGE)-$(VERSION)
	mkdir $(PACKAGE)-$(VERSION)
	tar -cf - -T MANIFEST | tar -C $(PACKAGE)-$(VERSION) -xf -
	tar zcf $(PACKAGE)-$(VERSION).tar.gz $(PACKAGE)-$(VERSION)
	rm -rf $(PACKAGE)-$(VERSION)
	ls -l $(PACKAGE)-$(VERSION).tar.gz

check-manifest:
	svn list | sort > .check-manifest; \
	sort MANIFEST > .orig-manifest; \
	diff -u .orig-manifest .check-manifest; rv=$$?; \
	rm -f .orig-manifest .check-manifest; \
	exit $$rv

#
# Debian packages.
#

dpkg:
	@if [ 0 != `cvs -q update | wc -l` ]; then \
	echo Please commit all changes to CVS first.; \
	exit 1; \
	fi
	$(MAKE) dist
	rm -rf /tmp/dbuild
	mkdir /tmp/dbuild
	cp $(PACKAGE)-$(VERSION).tar.gz \
	  /tmp/dbuild/$(PACKAGE)_$(VERSION).orig.tar.gz
	export CVSROOT=`cat CVS/Root`; \
	  cd /tmp/dbuild && \
	  cvs export \
	  -d $(PACKAGE)-$(VERSION) \
	  -D now merjis/freeware/pgocaml
	cd /tmp/dbuild/$(PACKAGE)-$(VERSION) && dpkg-buildpackage -rfakeroot
	rm -rf /tmp/dbuild/$(PACKAGE)-$(VERSION)
	ls -l /tmp/dbuild

#
# Developer documentation (in html/ subdirectory).
#

doc:
	rm -rf html
	mkdir html
	-ocamlfind ocamldoc $(OCAMLDOCFLAGS) -d html pGOCaml.mli pGOCaml.ml

#
# Miscelaneous.
#

force:

.PHONY:	depend dist check-manifest dpkg doc print_test

.SUFFIXES:	.cmo .cmi .cmx .ml .mli

