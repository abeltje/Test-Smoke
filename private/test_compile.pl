#! /usr/bin/perl
use warnings FATAL => 'all';
use strict;

# $Id$

use File::Spec;

my @scripts;
BEGIN {
    @scripts = qw( smokeperl.pl runsmoke.pl
                   synctree.pl patchtree.pl mailrpt.pl 
                   archiverpt.pl smokestatus.pl W32Configure.pl
                   Makefile.PL configsmoke.pl );

    push @scripts, map File::Spec->catfile(qw( lib Test Smoke ), $_ )
        => qw ( Util.pm Policy.pm SourceTree.pm
                Syncer.pm Patcher.pm Mailer.pm
                SysInfo.pm Reporter.pm
                BuildCFG.pm Smoker.pm );

    push @scripts, map File::Spec->catfile(qw( lib Test ), $_ )
        => qw ( Smoke.pm );
}

use Test::Simple tests => scalar @scripts;

my $dev_null = File::Spec->devnull;

foreach my $script ( @scripts ) {
    ok( system( qq{$^X  "-Ilib" "-c" "$script" > $dev_null 2>&1} ) == 0,
        "perl -c '$script'" );
}
