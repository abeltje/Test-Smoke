#! /bin/sh

echo 'Check compile'
perl test_compile.pl || exit

echo 'Check POD'
perl test_pod.pl     || exit

echo 'Create Makefile'
perl Makefile.PL
make
(make test) || exit
make dist
mv *.tar.gz ../

make veryclean
