#!/bin/sh

# This should be run with cron

# Uncomment this to be as nice as possible. (Jarkko)
# (renice -n 20 $$ >/dev/null 2>&1) || (renice 20 $$ >/dev/null 2>&1)

# Change your base dir here
export PC
PC=${1:-/usr/CPAN/perl-current}
CF=${2:-"`pwd`/smoke.cfg"}
TS_LF=${3:-"`pwd`/mktest.log"}

# Abigail pointed out that older rsync's might want older syntax as did Jarkko
# You could change this to a local directory to do smart copy
TS_RP=${4:-"ftp.linux.activestate.com::perl-current"}
# Set other environmental values here

export PATH
PATH="`pwd`:$PATH"

echo "Smoke $PC" >> "$TS_LF"

umask 0

cd "$PC" || exit 1
echo "Smokelog: builddir is $PC" > "$TS_LF"
make -i distclean > /dev/null 2>&1

# Jarkko says:
# Uncomment this to be random and not to hose the ActiveState server.
# perl -e 'sleep(rand(600))'

case "$TS_RP" in
*::perl-current) # rsync directory?
	(rsync -avz --delete $TS_RP . 2>&1) >>"$TS_LF"
	;;
*/perl-current)  # local directory?
        if test -d "$TS_RP"/.; then
            (rsync -avz --delete $TS_RP/. . 2>&1) >>"$TS_LF"
        else
            echo "$TS_RP is not a perl-current directory" >&2
            exit 1
        fi
	;;
esac

(mktest.pl "$CF" 2>&1) >>"$TS_LF" || echo mktest.pl exited with exit code $?

mkovz.pl 'smokers-reports@perl.org' "$PC" || echo mkovz.pl  exited with exit code $?
