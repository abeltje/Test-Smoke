#! /usr/bin/perl -w
use strict;

# $Id$

use Test::More;
my $verbose = 0;

use FindBin;
use lib $FindBin::Bin;

my @diffs;
BEGIN {
    @diffs = (
        { diff => 1 * 60*60 + 42 * 60 + 42.042,
          str  => '1 hour 42 minutes' },
        { diff => 1 * 24*60*60 + 2 * 60*60 + 4 * 60 + 2.042,
          str  => '1 day 2 hours 4 minutes' },
        { diff => 42 * 60 + 42.042,
          str  => '42 minutes 42 seconds' },
        { diff => 4 * 60 + 42.042,
          str  => '4 minutes 42.042 seconds' },
        { diff => 4 * 60*60 + 2.042,
          str  => '4 hours' },
        { diff => 1 * 24*60*60 + 4 * 60 + 2,
          str  => '1 day 4 minutes' },
    );

    plan tests =>  1 + @diffs;
}
BEGIN { use_ok "Test::Smoke::Util", qw( time_in_hhmm calc_timeout ) }


foreach my $diff ( @diffs ) {
    is time_in_hhmm( $diff->{diff} ), $diff->{str},
       "time_in_hhmm($diff->{diff}) $diff->{str}";
}
