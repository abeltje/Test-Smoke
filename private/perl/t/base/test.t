#! /usr/bun/perl -w
use strict;

use FindBin;
use Test::More tests => 2;



like( qx|$FindBin::Bin/../../miniperl|, qr|This is fake miniperl|, 
      "We found miniperl" );

like( qx|$FindBin::Bin/../../perl|, qr|This is fake perl|, 
      "We found perl" );

#ok( $ENV{PERLIO}, "\$ENV{PERLIO}=$ENV{PERLIO}" );
