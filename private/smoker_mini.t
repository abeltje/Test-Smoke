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
use Test::More tests => 16;
pass( $0 );

use Test::Smoke::BuildCFG;
use_ok( 'Test::Smoke::Smoker' );

{
    local *DEVNULL;
    open DEVNULL, ">". File::Spec->devnull;
    my $stdout = select( DEVNULL ); $| = 1;
    local *KEEPERR;
    open KEEPERR, ">&STDERR" and open STDERR,  ">&DEVNULL"
        unless $verbose;

    my %w32args = get_Win32_args;
    my $ccopt   = $w32args{is_win32} ? '-Accflags=-DDO_ERROR' : '--mini';
    my $cfg     = "$w32args{w32cct}\n=\n$ccopt\n=\n\n-DDEBUGGING";
    my $config  = Test::Smoke::BuildCFG->new( \$cfg );

    my $ddir   = catdir( $FindBin::Bin, 'perl' );
    my $l_name = catfile( $ddir, 'mktest.out' );
    local *LOG;
    open LOG, "> $l_name" or die "Cannot open($l_name): $!";

    my $smoker = Test::Smoke::Smoker->new( \*LOG => {
        ddir => $ddir,
        cfg  => $config,
        %w32args,
    } );

    isa_ok( $smoker, 'Test::Smoke::Smoker' );
    $smoker->mark_in;

    my $cwd = cwd();
    chdir $ddir or die "Cannot chdir($ddir): $!";

    $smoker->log( "Smoking patch 19000\n" );

    for my $bcfg ( $config->configurations ) {
        $smoker->mark_out; $smoker->mark_in;
        $smoker->make_distclean;
        ok( $smoker->Configure( $bcfg ), "Configure $bcfg" );

        $smoker->log( "\nConfiguration: $bcfg\n", '-' x 78, "\n" );
        my $stat = $smoker->make_;
        is( $stat, Test::Smoke::Smoker::BUILD_MINIPERL(), 
            "Could not build anything but 'miniperl'" );
        $smoker->log( "Unable to make anything but miniperl",
                      " in this configuration\n" );

        ok( $smoker->make_test_prep, "make test-prep" );
        local $ENV{PERL_FAIL_MINI} = $bcfg->has_arg( '-DDEBUGGING' ) ? 1 : 0;
        ok( $smoker->make_minitest( "$bcfg" ), "make minitest" );
    }

    $smoker->mark_out;

    ok( make_report( $ddir ), "Call Reporter" ) or diag( $@ );
    ok( my $report = get_report( $ddir ), "Got a report" );
    like( $report, q@/^M - M -\s*$/m@, "Got all M's for default config" );
    like( $report, q@/^Summary: FAIL\(M\)\s*$/m@, "Summary: FAIL(M)" );
    my $cfgopt = $w32args{w32cct} ? "$w32args{w32cct} $ccopt" : $ccopt;
    $cfgopt = "\Q$cfgopt\E";
    like( $report, qq@/^
        Failures:\\s+ \\(common-args\\)\\s+ $cfgopt \\s+
        \\[minitest\\s*\\]\\s*
        -DDEBUGGING \\s+
        t[\\\\/]smoke[\\\\/]minitest\\.+FAILED\\ at\\ test\\ 2
    /xm@, "Failures report" );
          

    select( DEVNULL ); $| = 1;
    $smoker->make_distclean;
    clean_mktest_stuff( $ddir );
    chdir $cwd;

    close STDERR and open STDERR, ">&KEEPERR" unless $verbose;
    select $stdout;
}

