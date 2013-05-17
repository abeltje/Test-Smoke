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
    $verbose > 1 and select $stdout;
    local *KEEPERR;
    open KEEPERR, ">&STDERR" and open STDERR, ">&DEVNULL"
        unless $verbose;

    my %w32args = get_Win32_args;
    my $cfg    = "$w32args{w32cct}\n=\n\n-DDEBUGGING";
    my $config = Test::Smoke::BuildCFG->new( \$cfg );

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
        local $ENV{EXEPERL} = $^X;
        ok( $smoker->Configure( $bcfg ), "Configure $bcfg" );

        $smoker->log( "\nConfiguration: $bcfg\n", '-' x 78, "\n" );
        my $stat = $smoker->make_;
        is( $stat, Test::Smoke::Smoker::BUILD_PERL(), "make" );
        ok( $smoker->make_test_prep, "make test-prep" );
        ok( $smoker->make_test( "$bcfg" ), "make test" );
    }

    ok( make_report( $ddir ), "Call Reporter" );
    ok( my $report = get_report( $ddir ), "Got a report" );
    like( $report, q@/^O O O O\s*$/m@, "Got all O's for default config" );
    like( $report, q@/^Summary: PASS\s*$/m@, "Summary: PASS" );
    unlike( $report, q@/^Failures:\s*$/m@, "No 'Failures:'" );

    select( DEVNULL ); $| = 1;
    $smoker->make_distclean;
    clean_mktest_stuff( $ddir );
    chdir $cwd;

    close STDERR and open STDERR, ">&KEEPERR" unless $verbose;
    select $stdout;
}

=head1 NAME

smoker.t - Attempt to test Test::Smoke::Smoker

=head1 SYNOPSIS

    $ cd private
    $ perl smoker.t

=head1 DESCRIPTION

This testfile attempts to be a real test for B<Test::Smoke::Smoker>.
The basic idea is to have a fake perl source-tree that has the ability
to mimic the actual smoke process:

    make -i distclean
    ./Configure [options]
    make
    make test-prep
    make _test

This involves some C-code that needs to be compiled and is highly
platform dependant. This is why this part of the test-suite for
B<Test::Smoke> is in a private directory and not included in the
distribution.

=head2 Configure

This is a "shell script" that calls F<Makefile.PL> to create a makefile.

=head2 Makefile.PL

This is a perl script that creates a platform dependant F<Makefile>.
It currently has two real options:

=over 4

=item B<--mini>

This option will make sure that C<< S<make miniperl> >> will succeed,
but C<make> (to create the F<perl> binary) will not succeed. This
option enables us to test this situation and (later) check that 
C<< S<make minitest> >> is called instead of C<< S<make test> >>.

=item B<--cc [path to cc]>

This option lets you specify a C-compiler in the hope that this part
of the test-suite can at least adapt to other platforms than my Linux
box.

=back

=head2 01test.c

You cannot actually call this a c program, but it does the job for now.

=head2 minitest.t, test.t

These files represent the perl core test-suite

=cut
