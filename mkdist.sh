#! /bin/sh

perl test_compile.pl || exit
perl test_pod.pl     || exit
PERL_MM_USE_DEFAULT=y
export PERL_MM_USE_DEFAULT
echo Set default input: $PERL_MM_USE_DEFAULT
perl Makefile.PL
make
(make test) || exit
make dist
mv *.tar.gz ../
make veryclean
rm -f */*/*/*~
