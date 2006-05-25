#! /usr/bin/perl -w
use strict;
use Data::Dumper;

# $Id$
use File::Spec::Functions qw( :DEFAULT devnull abs2rel rel2abs );
use Cwd;

use Test::More tests => 6;
use_ok( 'Test::Smoke::Smoker' );

my $debug = exists $ENV{SMOKE_DEBUG} && $ENV{SMOKE_DEBUG};

{
    my %config = (
        v => 0,
        ddir => 'perl-current',
        defaultenv => 1,
        testmake   => 'make',
    );

    local *LOG;
    open LOG, "> " . devnull();

    my $smoker = Test::Smoke::Smoker->new( \*LOG, %config );
    isa_ok( $smoker, 'Test::Smoke::Smoker' );

    my $ref = mkargs( \%config, 
                      Test::Smoke::Smoker->config( 'all_defaults' ) );
    $ref->{logfh} = \*LOG;

    is_deeply( $smoker, $ref, "Check arguments" );   

    close LOG;
}

{
    my @nok = (
        '../ext/Cwd/t/Cwd.....................FAILED at test 10',
        'op/magic.............................FAILED at test 37',
        '../t/op/die..........................FAILED at test 22',
        'ext/IPC/SysV/t/ipcsysv...............FAILED at test 1',

    );
    local *LOG;
    open LOG, "> " . devnull();

    my $smoker = Test::Smoke::Smoker->new( \*LOG,
        v => 0,
        ddir => cwd(),
    );

    my %tests = $smoker->_transform_testnames( @nok );
    my %raw = (
        '../ext/Cwd/t/Cwd.t'          => 'FAILED at test 10',
        '../t/op/magic.t'             => 'FAILED at test 37',
        '../t/op/die.t'               => 'FAILED at test 22',
        '../ext/IPC/SysV/t/ipcsysv.t' => 'FAILED at test 1',
    );
    my %expect;
    my $test_base = catdir( cwd, 't' );
    foreach my $test ( keys %raw ) {
        my $cname = canonpath( $test );
        my $test_name = rel2abs( $cname, $test_base );

        my $test_path = abs2rel( $test_name, $test_base );
        $test_path =~ tr!\\!/! if $^O eq 'MSWin32';
        $expect{ $test_path } = $raw{ $test };
    }
    is_deeply \%tests, \%expect, "transform testnames" or diag Dumper \%tests;

    $debug and diag Dumper { tests => \%tests, expect => \%expect };
    close LOG;
}

{
    my $harness_test = <<'EOHO';
Failed Test          Stat Wstat Total Fail  Failed  List of Failed
-------------------------------------------------------------------------------
../lib/Math/Trig.t    255 65280    29   12  41.38%  24-29
../lib/Net/hostent.t    6  1536     7   11 157.14%  2-7
../lib/Time/Local.t               135    1   0.74%  133
EOHO

    my %inconsistent = ( '../t/op/utftaint.t' => 1 );
    my $harness_all_ok = 0;
    my $full_re = Test::Smoke::Smoker::HARNESS_RE1();
    my $harness_out = join "", map {
        my( $name, $fail ) = 
            m/$full_re/;
        if ( $name ) {
            delete $inconsistent{ $name };
            my $dots = '.' x (40 - length $name );
            "    $name${dots}FAILED $fail\n";
        } else {
            ( $fail ) = m/^\s+(\d+(?:[-\s]+\d+)*)/;
            " " x 51 . "$fail\n";
        }
    } grep m/^\s+\d+(?:[-\s]+\d+)*/ ||
           m/$full_re/ => map {
        /All tests successful/ && $harness_all_ok++;
        $_;
    } split /\n/, $harness_test;

    is $harness_out, <<EOOUT, "Catch Test::Harness pre 2.60 output";
    ../lib/Math/Trig.t......................FAILED 24-29
    ../lib/Net/hostent.t....................FAILED 2-7
    ../lib/Time/Local.t.....................FAILED 133
EOOUT
}

{
    my $harness_test = <<'EOHO';
Failed Test        Stat Wstat Total Fail  List of Failed
-------------------------------------------------------------------------------
../t/op/utftaint.t    2   512    88    4  87-88
Failed 1/1 test scripts. 2/88 subtests failed.
Files=1, Tests=88,  1 wallclock secs ( 0.10 cusr +  0.02 csys =  0.12 CPU)
EOHO

    my %inconsistent = ( '../t/op/utftaint.t' => 1 );
    my $harness_all_ok = 0;
    my $full_re = Test::Smoke::Smoker::HARNESS_RE1();
    my $harness_out = join "", map {
        my( $name, $fail ) = 
            m/$full_re/;
        if ( $name ) {
            delete $inconsistent{ $name };
            my $dots = '.' x (40 - length $name );
            "    $name${dots}FAILED $fail\n";
        } else {
            ( $fail ) = m/^\s+(\d+(?:[-\s]+\d+)*)/;
            " " x 51 . "$fail\n";
        }
    } grep m/^\s+\d+(?:[-\s]+\d+)*/ ||
           m/$full_re/ => map {
        /All tests successful/ && $harness_all_ok++;
        $_;
    } split /\n/, $harness_test;

    is $harness_out,
       "    ../t/op/utftaint.t......................FAILED 87-88\n",
       "Catch Test::Harness 2.60 output";
}

sub mkargs {
    my( $set, $default ) = @_;

    my %mkargs = map {

        my $value = exists $set->{ $_ } 
            ? $set->{ $_ } : Test::Smoke::Smoker->config( $_ );
        ( $_ => $value )
    } keys %$default;

    return \%mkargs;
}
