# This file is a fixed makefile for dmake
#      Makefile.PL
#      $Id$
#
OPTIONS   =
CCTYPE    = GCC
FULLPERL  = C:\Perl\bin\perl.exe
TESTS     = smoke\die.t smoke\many.t smoke\minitest.t smoke\test.t
MINITESTS = smoke\minitest.t

.IF "$(CCTYPE)" == "BORLAND"
CCHOME          *= C:\borland\bcc55
CCCMD            = bcc
.ELIF "$(CCTYPE)" == "GCC"
CCHOME          *= C:\MinGW
CCCMD            = gcc
.ELSE
CCHOME          *= $(MSVCDIR)
CCCMD            = cl
.ENDIF
CCINCDIR        *= $(CCHOME)\include
CCLIBDIR        *= $(CCHOME)\lib

#BUILDOPT          =

##################### CHANGE THESE ONLY IF YOU MUST #####################

all: compile

minicompile:
[
	cd .. 
	$(CCCMD) 01test.c -o miniperl -DMINI
]

compile: minicompile
[
	cd ..
	$(CCCMD) 01test.c -o perl $(OPTIONS) $(BUILDOPT)
]

test-prep:
[
	cd ..\t
	copy $(FULLPERL) perl.exe
]

_test:
[
	cd ..\t
	$(FULLPERL) TEST $(TESTS)
]

test: test-prep 
	$(MAKE) _test

minitest: test-prep
[
	cd t
	$(FULLPERL) TEST $(MINITESTS)
]

distclean:
[
	cd ..
	rm -f perl.exe miniperl.exe t/perl.exe
	rm -f *~
	rm -f Makefile
	rm -f config.sh
]
