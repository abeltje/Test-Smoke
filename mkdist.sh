#! /bin/sh

# $Id$

for argv
    do case $argv in
        -t)   SMOKE_TEST_ONLY=1;;
        -d=*) SMOKE_DIST_DIR=`echo $argv | perl -pe 's/^-d=//'`;;
        -*)   if test "$argv" == "--help" || test "$argv" == "-h" ; then
                  echo ""
              else
                  echo "Unknown argument '$argv'"
              fi
              cat <<EOF && exit;;
Usage: $0 [-t] [-d=<directory]

    -t              Run tests only, do not make a tarball
    -d=<directory>  Taret directory for the tarball

EOF
    esac
done

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
for tst in smoker_*.t ; do
    perl $tst 2>/dev/null || (cd .. ; exit)
done
cd ..

if [ "$SMOKE_TEST_ONLY" == "1" ] ; then
    for tst in t/*.t ; do
        SMOKE_SKIP_SIGTEST=1 perl -Ilib $tst || exit
    done
    echo "SMOKE_TEST_ONLY was set, quitting..."
    exit
fi

# Clean up before we start
make -i veryclean > /dev/null 2>&1

# Now create the Makefile and and run the public test-suite
PERL_MM_USE_DEFAULT=y perl Makefile.PL

make

SMOKE_SKIP_SIGTEST=1 make test || exit

# Create the distribution and move it to the distribution directory
make dist
mv -v *.tar.gz $distdir

# Clean up!
make veryclean > /dev/null
rm -f */*/*/*~
