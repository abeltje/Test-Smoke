#! /bin/sh

# Set the directory where distributions are kept
distdir=./
if [ "`uname -n`" == "fikkie" ] ; then
    distdir=~/distro
fi


# Check if all the distributed perl-files compile
perl private/test_compile.pl || exit

# Check if all the distibuted files with POD are pod_ok
perl private/test_pod.pl     || exit

# Run the private Test::Smoke::Smoker tests
cd private
perl -MTest::Harness -e 'runtests( @ARGV, 1)' smoker_*.t || (cd .. ; exit)
cd ..

# Now create the Makefile and and run the public test-suite
PERL_MM_USE_DEFAULT=y
export PERL_MM_USE_DEFAULT
echo Set default input: $PERL_MM_USE_DEFAULT
perl Makefile.PL
make
(make test) || exit

# Create the distribution and move it to the distribution directory
make dist
mv -v *.tar.gz $distdir

# Clean up!
make veryclean > /dev/null
rm -f */*/*/*~
