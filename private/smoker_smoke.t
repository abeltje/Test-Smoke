#! /usr/bin/perl -w
use strict;
use Data::Dumper;
$| = 1;

use Cwd;
use FindBin;
use File::Spec::Functions;
use lib catdir( $FindBin::Bin, updir, 'lib' );
use lib catdir( $FindBin::Bin, updir );

use SmokertestLib;
use Test::More 'no_plan';

use Test::Smoke::BuildCFG;
use_ok( 'Test::Smoke::Smoker' );

{
    local *DEVNULL;
    open DEVNULL, ">". File::Spec->devnull;
    my $stdout = select( DEVNULL ); $| = 1;

    my $cfg    = "\n=\n\n-DDEBUGGING";
    my $config = Test::Smoke::BuildCFG->new( \$cfg );

    my $ddir   = catdir( $FindBin::Bin, 'perl' );
    my $l_name = catfile( $ddir, 'mktest.out' );
    local *LOG;
    open LOG, "> $l_name" or die "Cannot open($l_name): $!";
    select( (select( LOG ), $|++)[0] );

    my $smoker = Test::Smoke::Smoker->new( \*LOG => {
        ddir => $ddir,
        cfg  => $config,
    } );

    isa_ok( $smoker, 'Test::Smoke::Smoker' );

    my $cwd = cwd();
    chdir $ddir or die "Cannot chdir($ddir): $!";

    $smoker->log( "Smoking patch 19000\n" );

    for my $bcfg ( $config->configurations ) {
        $smoker->mark_out; $smoker->mark_in;
        $smoker->log( "\nConfiguration: $bcfg\n", '-' x 78, "\n" );

        local $ENV{PERL_FAIL_MINI} = $bcfg->has_arg( '-DDEBUGGING' ) ? 1 : 0;
        ok( $smoker->smoke( $bcfg ), "smoke($bcfg)" );
    }

    $smoker->mark_out;

    ok( make_report( $ddir ), "Call 'mkovz.pl'" ) or diag( $@ );
    ok( my $report = get_report( $ddir ), "Got a report" );
    like( $report, qr/^O O F F\s*$/m, "Got F for -DDEBUGGING" );
    like( $report, qr/^Summary: FAIL\(F\)\s*$/m, "Summary: FAIL(F)" );
    like( $report, qr/^
        $^O\s*
        \[stdio\/perlio\]
        -DDEBUGGING\s+
        \.\.\/t\/smoke\/minitest\.t\.+FAILED
    /xm, "Failures report" );
          

    select( DEVNULL ); $| = 1;
    $smoker->make_distclean;
    clean_mktest_stuff( $ddir );
    chdir $cwd;

    select $stdout;
}

