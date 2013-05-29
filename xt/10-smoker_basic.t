#! /usr/bin/perl -w
use strict;
use FindBin;

# $Id$
use vars qw( @output ); @output = ();
use Test::More tests => 6;

my $fh = select STDERR; $| = 1;
select $fh; $| = 1;

chdir "$FindBin::Bin/perl" or die "chdir(perl): $!";

if ( $^O eq 'MSWin32' ) {
    SKIP: {
        skip "Not yet finished for Windows", 6;
    }
} else {
    SKIP: {
        -f "Makefile" or skip "No makefile...", 1;
        is _run( 'make -i distclean' ), 0, "make -i distclean";
    }
    is _run( './Configure' ),       0, "Configure";
    is _run( 'make' ),              0, "make";
    is _run( 'make test-prep' ),    0, "make test-prep";
    is _run( 'make test'),          0, "make test";
    is _run( 'make distclean' ),    0, "make distclean";
}

sub _run {
    my $command = shift;
    @output = qx($command);
    return $? >> 8;
}
