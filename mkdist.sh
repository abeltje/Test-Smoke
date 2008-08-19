#! /bin/sh

# $Id$

SMOKE_PERL=perl
SMOKE_PROVE=prove
SMOKE_COVER=cover
for argv
    do case $argv in
        -t)   SMOKE_TEST_ONLY=1;;
        -e)   SMOKE_COVERAGE=1;;
        -c)   SMOKE_CI_FILES=1;;
        -s)   SMOKE_CI_SNAP=1;;
        -d=*) SMOKE_DIST_DIR=`echo $argv | perl -pe 's/^-d=//'`;;
        -588)  SMOKE_PERL=/opt/perl/perl588/bin/perl5.8.8
               SMOKE_PROVE=/opt/perl/perl588/bin/prove5.8.8
               SMOKE_COVER=/opt/perl/perl588/bin/cover;;
        -58)  SMOKE_PERL=/opt/perl/perl585/bin/perl5.8.5
              SMOKE_PROVE=/opt/perl/perl585/bin/prove5.8.5
              SMOKE_COVER=/opt/perl/perl585/bin/cover;;
        -510)  SMOKE_PERL=/opt/perl/perl5100/bin/perl5.10.0
               SMOKE_PROVE=/opt/perl/perl5100/bin/prove
               SMOKE_COVER=/opt/perl/perl5100/bin/cover;;
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
    -s              Commit this tree as a snapshot (set by -c)
    -58             Use the latest 5.8 installed (needed for -e)
    -59             Use the latest 5.9 installed
    -d=<directory>  Taret directory for the tarball

EOF
    esac
done

# Force snapshot for -c
if [ "$SMOKE_CI_FILES" == "1" ] ; then
    SMOKE_CI_SNAP=1
fi

# Set the directory where distributions are kept
distdir=./
UNAME=`uname -n`
if [ "$UNAME" == "droopy" -o "$UNAME" == "droopy.local" ] ; then
    distdir=~/distro
fi
if [ "$SMOKE_DIST_DIR" != "" ] ; then
    distdir=$SMOKE_DIST_DIR
fi
echo "Will put the distribution in: '$distdir'"
echo "Will use $SMOKE_PERL  for perl"
echo "Will use $SMOKE_PROVE for proving"

# Force testingmode for Coverage!
if [ "$SMOKE_COVERAGE" == "1" ] ; then
    SMOKE_TEST_ONLY=1
    echo "Will use $SMOKE_COVER for coverage"
fi

trap 'if [ $? ] ; then echo "An error while testing..."; fi ; exit' 0

# Check if all the distributed perl-files compile
# Check if all the distibuted files with POD are pod_ok
$SMOKE_PROVE private/test_*.pl || exit

if [ "$SMOKE_TEST_ONLY" == "1" ] ; then
    if [ "$SMOKE_COVERAGE" == "1" ] ; then
        $SMOKE_COVER -delete
        HARNESS_PERL_SWITCHES=-MDevel::Cover=+ignore,^\(?:t\|private\)/ \
            $SMOKE_PROVE -l t/*.t private/*.t
        PROVE_ERROR=$?
        $SMOKE_COVER
        if [ "$PROVE_ERROR" != "0" ] ; then exit $PROVE_ERROR ; fi
    else
        $SMOKE_PROVE -l private/*.t t/*.t || exit
    fi
    echo "SMOKE_TEST_ONLY was set, quitting..."
    trap 0
    exit
else
    $SMOKE_PROVE -l private/smoker_*.t || exit
fi

# Clean up before we start
make -i veryclean > /dev/null 2>&1

SMOKE_VERSION=`$SMOKE_PERL -Ilib -MTest::Smoke -e 'print Test::Smoke->VERSION'`
if [ "$SMOKE_VERSION" == "" ] ; then
    echo "No SMOKE_VERSION"
    exit
else
    echo "Create distribution for Test::Smoke $SMOKE_VERSION"
fi

# I keep forgetting about Changes, so automate:
svnchanges > Changes
if [ "$SMOKE_CI_FILES" == "1" ] ; then
    # Commit the newly generated Files
    cat <<EOF > svntargets.ci
Changes
EOF
    cat <<EOF > svnmsg.ci
* [AUTOCOMMIT]
  * Regenerate 'Changes'
EOF
    svn ci --targets svntargets.ci -F svnmsg.ci
    rm -f svntargets.ci
    rm -f svnmsg.ci
else
    echo "Skipping autocommit of regenerated Changes"
fi


# Now create the Makefile and and run the public test-suite
PERL_MM_USE_DEFAULT=y $SMOKE_PERL Makefile.PL

make

make test || exit

trap 0

# Create the distribution and move it to the distribution directory
make dist
mv -v *.tar.gz $distdir

## Autocommit the "make dist" regenerated files
#if [ "$SMOKE_CI_FILES" == "1" ] ; then
#    # Commit the newly generated Files
#    cat <<EOF > svntargets.ci
#SIGNATURES
#META.yml
#EOF
#    cat <<EOF > svnmsg.ci
#* [AUTOCOMMIT]
#  * Regenerate 'SIGNATURES', 'META.yml'
#EOF
#    svn ci --targets svntargets.ci -F svnmsg.ci
#    rm -f svntargets.ci
#    rm -f svnmsg.ci
#else
#    echo "Skipping autocommit of regenerated files"
#fi

# Clean up!
make veryclean > /dev/null
rm -f */*/*/*~

MKDIST_ADDDL=/data/apache/ztreet/adddl

SMOKE_SVNBASE='http://'
SMOKE_SOURCE=`svn info | perl -ne 's/^URL: //i and print'`
SMOKE_SOURCE=`echo $SMOKE_SOURCE |perl -pe 's|https://([^/]+)/|http://gromit/|'`

SMOKE_SNAP_BASE="http://gromit/svn/snapshots/"
SMOKE_SNAP_DIR="${SMOKE_SNAP_BASE}Test-Smoke-$SMOKE_VERSION"
SMOKE_SNAP_MSG=svnmsg.ci

if [ "$SMOKE_CI_SNAP" == "1" ] ; then
    echo "Snapshot: $SMOKE_SNAP_DIR"
    # Create a snapshot in the repository
    echo "* [SVN] Create a snapshot for $SMOKE_VERSION" > $SMOKE_SNAP_MSG
    svn cp $SMOKE_SOURCE $SMOKE_SNAP_DIR -F $SMOKE_SNAP_MSG
    rm -f $SMOKE_SNAP_MSG
    $SMOKE_DIST_NAME="Test-Smoke-$SMOKE_VERSION.tar.gz"
    echo "Add '$distdir/$SMOKE_DIST_NAME' for download"
    $MKDIST_ADDDL "$distdir/$SMOKE_DIST_NAME"
else
    echo "Skipping branch from '$SMOKE_SOURCE' ($SMOKE_VERSION)"
fi


