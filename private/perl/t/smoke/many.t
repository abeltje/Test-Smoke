#! /usr/bin/perl -w
use strict;

use Test::More tests => 100;

my $fail = exists $ENV{SMOKE_FAIL_TEST} && $ENV{SMOKE_FAIL_TEST};

for ( 0 .. 99 ) {
    if ( $fail && ($_ % 2 || $_ % 3) ) {
        fail( "Just testing fail" );
    } else {
        pass( "Just testing pass" );
    }
}
