#! /bin/sh

# $Id$

for argv
    do case $argv in
        -t)   SMOKE_TEST_ONLY=1;;
        -e)   SMOKE_COVER=1;;
        -c)   SMOKE_CI_FILES=1;;
        -d=*) SMOKE_DIST_DIR=`echo $argv | perl -pe 's/^-d=//'`;;
        -*)   if test "$argv" == "--help" || test "$argv" == "-h" ; then
                  echo ""
              else
                  echo "Unknown argument '$argv'"
              fi
              cat <<EOF && exit;;
Usage: $0 [-t] [-d=<directory]

    -t              Run tests only, do not make a tarball
    -e              Extend testing by running coverage (sets -t)
    -c              Commit the auto generated files Changes and SIGNATURE
    -d=<directory>  Taret directory for the tarball

EOF
    esac
done

# Force testingmode for Coverage!
if [ "$SMOKE_COVER" == "1" ] ; then
    SMOKE_TEST_ONLY=1
fi

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

if [ "$SMOKE_TEST_ONLY" == "1" -a "$SMOKE_COVER" == "1" ] ; then
    cover -delete
    save_perl5opt=$PERL5OPT
    PERL5OPT="-MDevel::Cover $save_perl5opt"
fi
echo "Should be running with '$PERL5OPT'"

# Run the private Test::Smoke::Smoker tests
incdir="`pwd`/lib"
for tst in private/smoker_*.t ; do
    perl -I$incdir $PERL5OPT $tst  || exit
done

if [ "$SMOKE_TEST_ONLY" == "1" ] ; then
    for tst in t/*.t ; do
        SMOKE_SKIP_SIGTEST=1 perl -I$incdir $PERL5OPT $tst ; #|| exit
    done
    if [ "$SMOKE_COVER" == "1" ]; then
        cover
        PERL5OPT=$save_perl5opt
    fi
    echo "SMOKE_TEST_ONLY was set, quitting..."
    exit
fi

# Clean up before we start
make -i veryclean > /dev/null 2>&1

if [ "$SMOKE_CI_FILES" == "1" ] ; then
    # I keep forgetting about Changes, so automate:
    svnchanges > Changes
    perl -Ilib -MTest::Smoke -wle \
    'system qq/svn ci Changes -m "* regen Changes for $Test::Smoke::VERSION"/'
else
    echo "Skipping commit of 'Changes'"
fi

# Now create the Makefile and and run the public test-suite
PERL_MM_USE_DEFAULT=y perl Makefile.PL

make

SMOKE_SKIP_SIGTEST=1 make test || exit

# Create the distribution and move it to the distribution directory
perl -i -pe 's/^#?local-user abeltje/local-user abeltje/' ~/.gnupg/options
make dist
perl -i -pe 's/^local-user abeltje/#local-user abeltje/' ~/.gnupg/options
mv -v *.tar.gz $distdir

# Clean up!
make veryclean > /dev/null
rm -f */*/*/*~

if [ "$SMOKE_CI_FILES" == "1" ] ; then
    # Also commit the newly generated SIGNATURE
    perl -Ilib -MTest::Smoke -wle \
    'system qq/svn ci SIGNATURE -m "* regen SIGNATURE for $Test::Smoke::VERSION"/'
else
    echo "Skipping commit of 'SIGNATURE'"
fi
