#! perl -w
use strict;

# $Id$

my @fixed;
BEGIN { # freeze localtime() for testing
    use Time::Local;
    @fixed = ( 0, 42, 21, 1, 7, 2003 );
    my $fixed_time = timelocal( @fixed );
    *CORE::GLOBAL::localtime = sub {
        CORE::localtime( $fixed_time );
      }
}

use Test::More tests => 6;
BEGIN { use_ok( 'Test::Smoke::Util', 'calc_timeout' ) }

my @localtime = (localtime)[0..5]; $localtime[5] += 1900;
is_deeply( \@localtime, \@fixed, "localtime() is fixed" );
is( calc_timeout( '22:00' ), 60*18, "Absolute time from 21:00" );
is( calc_timeout( '20:42' ), 60*60*23, "Absolute time from 22:42" );

is( calc_timeout( '+0:42' ), 60*42, "Relative time +0:42" );
is( calc_timeout( '+47:45' ), 60*(60*47+45), "Relative time +47:45" );
