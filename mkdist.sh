#! /bin/sh

# $Id$
# Set the directory where distributions are kept
distdir=./
if [ "`uname -n`" == "fikkie" ] ; then
    distdir=~/distro
fi
if [ "$SMOKE_DIST_DIR" != "" ] ; then
    distdir=$SMOKE_DIST_DIR
fi
echo "Will put the distribution in: '$distdir'"

# Check if all the distributed perl-files compile
perl private/test_compile.pl || exit

# Check if all the distibuted files with POD are pod_ok
perl private/test_pod.pl     || exit

# Run the private Test::Smoke::Smoker tests
cd private
for test in smoker_*.t; do
    perl $test 2>/dev/null || (cd .. ; exit)
done
cd ..

if [ "$SMOKE_TEST_ONLY" == "1" ] ; then
    echo "SMOKE_TEST_ONLY was set, quitting..."
    exit
fi

# Now create the Makefile and and run the public test-suite
PERL_MM_USE_DEFAULT=y
export PERL_MM_USE_DEFAULT
echo Set default input: $PERL_MM_USE_DEFAULT
perl Makefile.PL
make
(SMOKE_SKIP_SIGTEST=1 make test) || exit

# Create the distribution and move it to the distribution directory
make dist
mv -v *.tar.gz $distdir

# Clean up!
make veryclean > /dev/null
rm -f */*/*/*~
