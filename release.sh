#! /bin/bash

GITBRANCH=master
SKIPSTATUS=0
SKIPPRIVATE=0
SKIPTESTS=0
SKIPALLTESTS=0
NOAUTOCOMMIT=0

for argv ; do
    case $argv in
        -b=*)           GITBRANCH=`echo $argv | perl -pe 's/^-b=//;'`
            ;;
        -d=*)           DIST_DIR=`echo $argv | perl -pe 's/^-d=//'`
            ;;
        -skipstatus)    SKIPSTATUS=1
            ;;
        -skipalltests)  SKIPALLTESTS=1
            ;;
        -skipprivate)   SKIPPRIVATE=1
            ;;
        -skiptests)     SKIPTESTS=1
            ;;
        -noautocommit)  NOAUTOCOMMIT=1
            ;;
        *)              echo "Warning: unknown option: '$argv'";
            ;;
    esac
done

# Set the directory where distributions are kept
distdir=./
UNAME=`uname -n | perl -ne '/^([^.]+)/ and print $1'`
if [ $UNAME == "diefenbaker" ] ; then
    distdir=~/distro
fi
if [ "$DIST_DIR" != "" ] ; then
    distdir=$DIST_DIR
fi
echo "Will put the distribution in: '$distdir'"

# Check git branch
mybranch=`git branch | perl -ne '/^\*\s(\S+)/ and print $1'`
if [ "$mybranch" != "$GITBRANCH" ] ; then
    echo "Branch not ok, found '$mybranch' expected '$GITBRANCH'"
    exit 10
fi

# Check git status -s
if [ "$SKIPSTATUS" != "1" ] ; then
    mystatus=`git status -s`
    if [ "$mystatus" != "" ] ; then
        echo "Status not clean: $mystatus";
        exit 15
    fi
else
    echo "Skipping 'git status -s'"
fi

if [ -f "Makefile" ] ; then
    make -i veryclean > /dev/null 2>&1
fi

if [ "$SKIPALLTESTS" != "1" ] ; then
    if [ "$SKIPPRIVATE" != "1" ] ; then
        # Run the private testsuite
        prove -wl private/*.pl private/*.t
        if [ $? -gt 0 ] ; then
            echo "Private tests not ok: $?"
            exit 20
        fi
    else
        echo "Skipped private tests"
    fi
    if [ "$SKIPtests" != "1" ] ; then
        # Run the public testsuite
        prove -wl t/*.t
        if [ $? -gt 0 ] ; then
            echo "Public tests not ok: $?"
            exit 25
        fi
    else
        echo "Skipped public tests"
    fi
else
    echo "Skipped all tests"
fi

# Update the version in lib/Test/Smoke.pm
myoldversion=`perl -Ilib -MTest::Smoke -e 'print Test::Smoke->VERSION'`
perl -i -pe '/^(?:our\s*)?\$VERSION\s*=\s*/ && s/(\d+\.\d+)/sprintf "%.2f", $1+0.01/e' lib/Test/Smoke.pm
mynewversion=`perl -Ilib -MTest::Smoke -e 'print Test::Smoke->VERSION'`

# Update the Changes file
line="________________________________________________________________________________"
cat <<EOF > Changes
Changes on `date '+%Y-%m-%d'` for github repository at:
`git remote show origin | grep 'URL:'`

Enjoy!

`git log --name-status --pretty="$line%n[%h] by %an on %aD%n%n%w(76,4,8)%+B"`
EOF

echo "Distribution for $mynewversion (was $myoldversion)"
if [ "$NOAUTOCOMMIT" != "1" ]; then
    git commit -m "Autocommit for distribution Test::Smoke $mynewversion" lib/Test/Smoke.pm Changes
    git tag "Test-Smoke-$mynewversion"
    git push --all
fi

PERL_MM_USE_DEFAULT=y perl Makefile.PL
make all test
if [ $? -gt 0 ] ; then
    echo "make test failed: $?"
    exit 30
fi
make dist
mv -v *.tar.gz $distdir
make veryclean > /dev/null 2>&1
