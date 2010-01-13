#! /usr/bin/perl -w
use strict;

use Test::More;
$! = 0;

if ( exists $ENV{SMOKE_FAIL_TEST} && $ENV{SMOKE_FAIL_TEST} ) {
    die "This test is supposed to die() before a plan()!";
} else {
    plan tests => 1;
    pass( "Die test won't die() now" );
}
