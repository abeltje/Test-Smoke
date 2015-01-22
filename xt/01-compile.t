#! /usr/bin/perl -w
use strict;

use File::Spec::Functions qw/:DEFAULT devnull/;
use File::Find;

my @to_compile;
BEGIN {
    @to_compile = qw( smokeperl.pl runsmoke.pl
                   synctree.pl patchtree.pl mailrpt.pl
                   archiverpt.pl smokestatus.pl W32Configure.pl
                   Makefile.PL configsmoke.pl chkbcfg.pl sysinfo.pl );

    find sub {
        -f or return;
        /\.pm$/ or return;
        push @to_compile, $File::Find::name;
    }, catdir('lib', 'Test');
}

use Test::Simple tests => scalar @to_compile;

my $dev_null = devnull();

foreach my $src ( @to_compile ) {
    ok( system( qq{$^X  "-Ilib" "-c" "$src" > $dev_null 2>&1} ) == 0,
        "perl -c '$src'" );
}
