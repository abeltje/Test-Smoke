#! /usr/bin/perl -w
use strict;

use FindBin;
use Test::More tests => 4;

my $fail = exists $ENV{PERL_FAIL_MINI} && $ENV{PERL_FAIL_MINI};

like( qx|$FindBin::Bin/../../miniperl|, qr|This is fake miniperl|, 
      "We found miniperl" );

if ( $fail ) {
    ok( 0, "Just testing fail" );
    ok( 0, "Just testing fail" );
} else {
    ok( 1, "Just testing pass" );
    ok( 1, "Just testing pass" );
}
pass( "Just testing pass" );
