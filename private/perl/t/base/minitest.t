#! /usr/bun/perl -w
use strict;

use FindBin;
use Test::More tests => 2;

my $fail = 0;

like( qx|$FindBin::Bin/../../miniperl|, qr|This is fake miniperl|, 
      "We found miniperl" );

if ( $fail ) {
    fail( "Just testing fail" );
} else {
    pass( "Just testing pass" );
}

