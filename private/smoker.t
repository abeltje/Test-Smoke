#! /usr/bin/perl -w
use strict;
use Data::Dumper;
$| = 1;

use Cwd;
use FindBin;
use File::Spec::Functions;
use lib catdir( updir, 'lib' );
use lib catdir( updir );

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

    my $smoker = Test::Smoke::Smoker->new( \*LOG => {
        ddir => $ddir,
        cfg  => $config,
    } );

    isa_ok( $smoker, 'Test::Smoke::Smoker' );
    $smoker->mark_in;

    my $cwd = cwd();
    chdir $ddir or die "Cannot chdir($ddir): $!";

    $smoker->log( "Smoking patch 19000\n" );

    for my $bcfg ( $config->configurations ) {
        $smoker->mark_out; $smoker->mark_in;
        $smoker->make_distclean;
        ok( $smoker->Configure( '' ), "Configure" );

        $smoker->log( "\nConfiguration: $bcfg\n", '-' x 78, "\n" );
        my $stat = $smoker->make_;
        is( $stat, 1, "make" );
        ok( $smoker->make_test( "$bcfg" ), "make test" );
    }

    $smoker->make_distclean;
    chdir $cwd;

    select $stdout;
}

{
    local *DEVNULL;
    open DEVNULL, ">". File::Spec->devnull;
    my $stdout = select( DEVNULL ); $| = 1;

    my $cfg    = "--mini\n=\n\n-DDEBUGGING";
    my $config = Test::Smoke::BuildCFG->new( \$cfg );

    my $ddir   = catdir( $FindBin::Bin, 'perl' );
    my $l_name = catfile( $ddir, 'mktest.out' );
    local *LOG;
    open LOG, "> $l_name" or die "Cannot open($l_name): $!";

    my $smoker = Test::Smoke::Smoker->new( \*LOG => {
        ddir => $ddir,
        cfg  => $config,
    } );

    isa_ok( $smoker, 'Test::Smoke::Smoker' );
    $smoker->mark_in;

    my $cwd = cwd();
    chdir $ddir or die "Cannot chdir($ddir): $!";

    $smoker->log( "Smoking patch 19000\n" );

    for my $bcfg ( $config->configurations ) {
        $smoker->mark_out; $smoker->mark_in;
        $smoker->make_distclean;
        ok( $smoker->Configure( $bcfg ), "Configure" );

        $smoker->log( "\nConfiguration: $bcfg\n", '-' x 78, "\n" );
        my $stat = $smoker->make_;
        is( $stat, -1, "Could not build anything but 'miniperl'" );
        ok( $smoker->make_minitest( "$bcfg" ), "make minitest" );
    }

    $smoker->mark_out;

    chdir $cwd;

    select $stdout;
}
