#! /usr/bin/perl
use warnings FATAL => 'all';
use strict;

use File::Spec;

my @scripts;
BEGIN {
    @scripts = qw( mktest.pl mkovz.pl smokeperl.pl
                   synctree.pl patchtree.pl mailrpt.pl W32Configure.pl
                   Makefile.PL Configure.pl configsmoke.pl );

    push @scripts, map File::Spec->catfile(qw( lib Test Smoke ), $_ )
        => qw ( Util.pm Policy.pm SourceTree.pm
                Syncer.pm Patcher.pm Mailer.pm
                BuildCFG.pm Smoker.pm );

    push @scripts, map File::Spec->catfile(qw( lib Test ), $_ )
        => qw ( Smoke.pm );
}

use Test::Simple tests => scalar @scripts;

my $dev_null = File::Spec->devnull;

foreach my $script ( @scripts ) {
    ok( system( qq{$^X  "-Ilib" "-c" "$script" > $dev_null 2>&1} ) == 0,
        "perl -c '$script' okay" );
}
