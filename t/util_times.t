#! /usr/bin/perl -w
use strict;

# $Id$

use Test::More;
my $verbose = 0;

use FindBin;
use lib $FindBin::Bin;

my( @diffs, @fixed );
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
        { diff => 2 * 24*60*60 + 4 * 60 + 2,
          str  => '2 days 4 minutes' },
        { diff => 60,
          str  => '1 minute' },
    );

    use Time::Local;
    @fixed = ( 0, 42, 21, 1, 7, 2003 );
    my $fixed_time = timelocal( @fixed );
    *CORE::GLOBAL::localtime = sub {
        CORE::localtime( $fixed_time );
    };

    plan tests =>  1 + @diffs + 6;
}
BEGIN { use_ok "Test::Smoke::Util", qw( time_in_hhmm calc_timeout ) }

# Tests for time_in_hhmm()
foreach my $diff ( @diffs ) {
    is time_in_hhmm( $diff->{diff} ), $diff->{str},
       "time_in_hhmm($diff->{diff}) $diff->{str}";
}

# Tests for calc_timeout()
my @localtime = (localtime)[0..5]; $localtime[5] += 1900;
is_deeply( \@localtime, \@fixed, "localtime() is fixed" );
is( calc_timeout( '22:00' ), 60*18, "Absolute time from 21:00" );
is( calc_timeout( '20:42' ), 60*60*23, "Absolute time from 22:42" );

is( calc_timeout( '+0:42' ), 60*42, "Relative time +0:42" );
is( calc_timeout( '+47:45' ), 60*(60*47+45), "Relative time +47:45" );
is( calc_timeout( '' ), 0, 'No input' );
