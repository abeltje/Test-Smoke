#! /usr/bin/perl -w
use strict;

use File::Spec::Functions qw/:DEFAULT devnull/;
use File::Find;

my @to_compile;
BEGIN {
    find sub {
        -f or return;
        /\.pm$/ or return;
        push @to_compile, $File::Find::name;
    }, catdir('lib', 'Test');
    find sub {
        -f or return;
        /\.pl$/ or return;
        push @to_compile, $File::Find::name;
    }, 'bin';
}

use Test::Simple tests => scalar @to_compile;

my $redirect1 = $ENV{TEST_VERBOSE} ? '' : '>' . devnull();

foreach my $src ( @to_compile ) {
    ok( system( qq{$^X  "-Ilib" "-wc" "$src" $redirect1 2>&1} ) == 0,
        "perl -c '$src'" );
}
