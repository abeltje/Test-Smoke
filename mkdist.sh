#! /bin/sh

perl test_compile.pl || exit
perl test_pod.pl     || exit
perl Makefile.PL
make
(make test) || exit
make dist
mv *.tar.gz ../
make veryclean
