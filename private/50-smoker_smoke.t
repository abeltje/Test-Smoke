#! /usr/bin/perl -w
use strict;
use Data::Dumper;
$| = 1;

# $Id$

my $verbose = exists $ENV{SMOKE_VERBOSE} ? $ENV{SMOKE_VERBOSE} : 0;

use Cwd;
use FindBin;
use File::Spec::Functions;
#use lib catdir( $FindBin::Bin, updir, 'lib' );
#use lib catdir( $FindBin::Bin, updir );
use lib $FindBin::Bin;

use SmokertestLib;
use Test::More tests => 18;
pass( $0 );

use Test::Smoke::BuildCFG;
use_ok( 'Test::Smoke::Smoker' );

{
    local *DEVNULL;
    open DEVNULL, ">". File::Spec->devnull;
    my $stdout = select( DEVNULL ); $| = 1;
    $verbose > 1 and select $stdout;
    local *KEEPERR;
    open KEEPERR, ">&STDERR" and  open STDERR, ">&DEVNULL"
        unless $verbose;

    my %w32args = get_Win32_args;
    my $cfg    = "$w32args{w32cct}\n=\n\n-DDEBUGGING";
    my $config = Test::Smoke::BuildCFG->new( \$cfg );

    my $ddir   = catdir( $FindBin::Bin, 'perl' );
    my $l_name = catfile( $ddir, 'mktest.out' );
    local *LOG;
    open LOG, "> $l_name" or die "Cannot open($l_name): $!";
    select( (select( LOG ), $|++)[0] );

    my $smoker = Test::Smoke::Smoker->new( \*LOG => {
        ddir => $ddir,
        cfg  => $config,
        %w32args,
    } );

    isa_ok( $smoker, 'Test::Smoke::Smoker' );

    my $cwd = cwd();
    chdir $ddir or die "Cannot chdir($ddir): $!";

    $smoker->log( "Smoking patch 19000\n" );

    for my $bcfg ( $config->configurations ) {
        $smoker->mark_out; $smoker->mark_in;
        $smoker->log( "\nConfiguration: $bcfg\n", '-' x 78, "\n" );

        local $ENV{PERL_FAIL_MINI} = $bcfg->has_arg( '-DDEBUGGING' ) ? 1 : 0;
        local $ENV{EXEPERL} = $^X;
        ok( $smoker->smoke( $bcfg ), "smoke($bcfg)" );
    }

    $smoker->mark_out;

    ok( make_report( $ddir ), "Call 'mkovz.pl'" ) or diag( $@ );
    ok( my $report = get_report( $ddir ), "Got a report" );
    like( $report, q@/^O O F F\s*$/m@, "Got F for -DDEBUGGING" );
    like( $report, q@/^Summary: FAIL\(F\)\s*$/m@, "Summary: FAIL(F)" );
    like( $report, q@/^
        \[stdio\/perlio\]\s*
        -DDEBUGGING.*\s+
        .*smoke\/minitest\.t\.+FAILED
    /xm@, "Failures report" );
          

    select( DEVNULL ); $| = 1;
    $smoker->make_distclean;
    clean_mktest_stuff( $ddir );
    chdir $cwd;

    close STDERR and open STDERR, ">&KEEPERR" unless $verbose;
    select $stdout;
}

{
    local *DEVNULL;
    open DEVNULL, ">". File::Spec->devnull;
    my $stdout = select( DEVNULL ); $| = 1;
    $verbose > 1 and select $stdout;
    local *KEEPERR;
    open KEEPERR, ">&STDERR" and  open STDERR, ">&DEVNULL"
        unless $verbose;

    my %w32args = get_Win32_args;
    my $cfg    = "$w32args{w32cct}\n=\n\n-DDEBUGGING";
    my $config = Test::Smoke::BuildCFG->new( \$cfg );

    my $ddir   = catdir( $FindBin::Bin, 'perl' );
    my $l_name = catfile( $ddir, 'mktest.out' );
    local *LOG;
    open LOG, "> $l_name" or die "Cannot open($l_name): $!";
    select( (select( LOG ), $|++)[0] );

    # we need te cheat for Test::Harness 3
    require Test::Harness;
    my $hasharness3 = Test::Harness->VERSION >= 3;
    my $smoker = Test::Smoke::Smoker->new( \*LOG => {
        ddir        => $ddir,
        cfg         => $config,
        harnessonly => 1,
        hasharness3 => $hasharness3,
        v           => $verbose,
        %w32args,
    } );

    isa_ok( $smoker, 'Test::Smoke::Smoker' );

    my $cwd = cwd();
    chdir $ddir or die "Cannot chdir($ddir): $!";

    $smoker->log( "Smoking patch 19000\n" );

    for my $bcfg ( $config->configurations ) {
        $smoker->mark_out; $smoker->mark_in;
        $smoker->log( "\nConfiguration: $bcfg\n", '-' x 78, "\n" );

        local $ENV{PERL_FAIL_MINI} = $bcfg->has_arg( '-DDEBUGGING' ) ? 1 : 0;
        local $ENV{EXEPERL} = $^X;
        ok( $smoker->smoke( $bcfg ), "smoke($bcfg)" );
    }

    $smoker->mark_out;

    ok( make_report( $ddir ), "Call 'mkovz.pl'" ) or diag( $@ );
    ok( my $report = get_report( $ddir ), "Got a report" );
    like( $report, q@/^O O F F\s*$/m@, "Got F for -DDEBUGGING" );
    like( $report, q@/^Summary: FAIL\(F\)\s*$/m@, "Summary: FAIL(F)" );
    like( $report, q@/^
        \[stdio\/perlio\]\s*
        -DDEBUGGING.*\s+
        .*smoke\/minitest\.t\.+FAILED\s+
        \d(?:[, -]\d+)*
    /xm@, "Failures report" );
          

    select( DEVNULL ); $| = 1;
    $smoker->make_distclean;
    clean_mktest_stuff( $ddir );
    chdir $cwd;

    close STDERR and open STDERR, ">&KEEPERR" unless $verbose;
    select $stdout;
}
