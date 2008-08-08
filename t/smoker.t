#! /usr/bin/perl -w
use strict;
use Data::Dumper;

# $Id$
use File::Spec::Functions qw( :DEFAULT devnull abs2rel rel2abs );
use Cwd;

use lib 't';
use TestLib;

use Test::More tests => 36;
use_ok( 'Test::Smoke::Smoker' );

my $debug   = exists $ENV{SMOKE_DEBUG} && $ENV{SMOKE_DEBUG};
my $verbose = exists $ENV{SMOKE_VERBOSE} ? $ENV{SMOKE_VERBOSE} : 0;

local *LOG;
open LOG, "> " . devnull();

{
    my %config = (
        v => $verbose,
        ddir => 'perl-current',
        defaultenv => 1,
        testmake   => 'make',
    );

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

    my $smoker = Test::Smoke::Smoker->new( \*LOG,
        v => 0,
        ddir => cwd(),
    );

    my %tests = $smoker->_transform_testnames( @nok );
    my %raw = (
        'ext/Cwd/t/Cwd.t'          => 'FAILED at test 10',
        't/op/magic.t'             => 'FAILED at test 37',
        't/op/die.t'               => 'FAILED at test 22',
        'ext/IPC/SysV/t/ipcsysv.t' => 'FAILED at test 1',
    );
    my %expect;
    my $test_base = catdir( cwd, 't' );
    foreach my $test ( keys %raw ) {
        my $test_path = $smoker->_normalize_testname( $test );

        $expect{ $test_path } = $raw{ $test };
    }
    is_deeply \%tests, \%expect, "transform testnames" or diag Dumper \%tests;

    $debug and diag Dumper { tests => \%tests, expect => \%expect };
    close LOG;
}

{
    my $smoker = Test::Smoke::Smoker->new( \*LOG, v => $verbose );
    isa_ok $smoker, 'Test::Smoke::Smoker';
    my @harness_test = split /\n/, <<'EOHO';
Failed Test          Stat Wstat Total Fail  Failed  List of Failed
-------------------------------------------------------------------------------
../lib/Math/Trig.t    255 65280    29   12  41.38%  24-29
../lib/Net/hostent.t    6  1536     7   11 157.14%  2-7
../lib/Time/Local.t               135    1   0.74%  133
EOHO

    my %inconsistent = map +( $_ => 1 ) => grep length $_ => map {
        m/(\S+\.t)\s+/ ? $1 : ''
    } @harness_test;

    my $all_ok;
    my $harness_out = $smoker->_parse_harness_output( \%inconsistent, $all_ok,
                                                      @harness_test );

    is $harness_out, <<EOOUT, "Catch Test::Harness pre 2.60 output";
    ../lib/Math/Trig.t......................FAILED 24-29
    ../lib/Net/hostent.t....................FAILED 2-7
    ../lib/Time/Local.t.....................FAILED 133
EOOUT
    is keys %inconsistent, 0, "No inconssistent test results"
        or diag Dumper \%inconsistent;
}

{
    my $smoker = Test::Smoke::Smoker->new( \*LOG, v => $verbose );
    isa_ok $smoker, 'Test::Smoke::Smoker';
    my @harness_test = split /\n/, <<'EOHO';
Failed Test  Stat Wstat Total Fail  Failed  List of Failed
-------------------------------------------------------------------------------
smoke/die.t   255 65280    ??   ??       %  ??
smoke/many.t   83 21248   100   83  83.00%  2-6 8-12 14-18 20-24 26-30 32-36
                                            38-42 44-48 50-54 56-60 62-66 68-72
                                            74-78 80-84 86-90 92-96 98-100
EOHO

    my %inconsistent = map +( $_ => 1 ) => grep length $_ => map {
        m/(\S+\.t)\s+/ ? $1 : ''
    } @harness_test;

    my $all_ok;
    my $harness_out = $smoker->_parse_harness_output( \%inconsistent, $all_ok,
                                                      @harness_test );

    is $harness_out, <<EOOUT, "Catch Test::Harness pre 2.60 output";
    smoke/die.t.............................FAILED ??
    smoke/many.t............................FAILED 2-6 8-12 14-18 20-24 26-30 32-36
                                                   38-42 44-48 50-54 56-60 62-66 68-72
                                                   74-78 80-84 86-90 92-96 98-100
EOOUT
    is keys %inconsistent, 0, "No inconssistent test results";
}

{
    my $smoker = Test::Smoke::Smoker->new( \*LOG, v => $verbose );
    isa_ok $smoker, 'Test::Smoke::Smoker';
    my @harness_test = split /\n/, <<'EOHO';
Failed Test        Stat Wstat Total Fail  List of Failed
-------------------------------------------------------------------------------
../t/op/utftaint.t    2   512    88    4  87-88
Failed 1/1 test scripts. 2/88 subtests failed.
Files=1, Tests=88,  1 wallclock secs ( 0.10 cusr +  0.02 csys =  0.12 CPU)
EOHO

    my %inconsistent = map +( $_ => 1 ) => grep length $_ => map {
        m/(\S+\.t)\s+/ ? $1 : ''
    } @harness_test;

    my $all_ok;
    my $harness_out = $smoker->_parse_harness_output( \%inconsistent, $all_ok,
                                                      @harness_test );

    is $harness_out,
       "    ../t/op/utftaint.t......................FAILED 87-88\n",
       "Catch Test::Harness 2.60 output";
    is keys %inconsistent, 0, "No inconssistent test results";
}

{
    my $smoker = Test::Smoke::Smoker->new( \*LOG, v => $verbose );
    isa_ok $smoker, 'Test::Smoke::Smoker';
    my @harness_test = split /\n/, <<'EOHO';
Failed Test  Stat Wstat Total Fail  List of Failed
-------------------------------------------------------------------------------
smoke/die.t   255 65280    ??   ??  ??
smoke/many.t   83 21248   100   83  2-6 8-12 14-18 20-24 26-30 32-36 38-42 44-
                                    48 50-54 56-60 62-66 68-72 74-78 80-84 86-
                                    90 92-96 98-100
EOHO

    my %inconsistent = map +( $_ => 1 ) => grep length $_ => map {
        m/(\S+\.t)\s+/ ? $1 : ''
    } @harness_test;

    my $all_ok;
    my $harness_out = $smoker->_parse_harness_output( \%inconsistent, $all_ok,
                                                      @harness_test );

    is $harness_out, <<EOOUT, "Catch Test::Harness 2.60 output";
    smoke/die.t.............................FAILED ??
    smoke/many.t............................FAILED 2-6 8-12 14-18 20-24 26-30 32-36 38-42 44-
                                                   48 50-54 56-60 62-66 68-72 74-78 80-84 86-
                                                   90 92-96 98-100
EOOUT

    is keys %inconsistent, 0, "No inconssistent test results";
}

{
    my $smoker = Test::Smoke::Smoker->new( \*LOG, v => $verbose );
    isa_ok $smoker, 'Test::Smoke::Smoker';
    my @harness_test = split /\n/, <<'EOHO';
Failed Test  Stat Wstat Total Fail  List of Failed
-------------------------------------------------------------------------------
smoke/die.t   255 65280    ??   ??  ??
smoke/many.t   83 21248   100   83  2-6 8-12 14-18 20-24 26-30 32-36 38-42 44-
                                    48 50-54 56-60 62-66 68-72 74-78 80-84 86-
                                    90 92-96 98-100
EOHO

    my %inconsistent = map +( $_ => 1 ) => grep length $_ => map {
        m/(\S+\.t)\s+/ ? $1 : ''
    } @harness_test;
    $inconsistent{ '../t/op/utftaint.t' } = 1;

    my $all_ok;
    my $harness_out = $smoker->_parse_harness_output( \%inconsistent, $all_ok,
                                                      @harness_test );

    is $harness_out, <<EOOUT, "Catch Test::Harness 2.60 output";
    smoke/die.t.............................FAILED ??
    smoke/many.t............................FAILED 2-6 8-12 14-18 20-24 26-30 32-36 38-42 44-
                                                   48 50-54 56-60 62-66 68-72 74-78 80-84 86-
                                                   90 92-96 98-100
EOOUT

    is keys %inconsistent, 1, "One inconssistent test result";
}

{
    my $smoker = Test::Smoke::Smoker->new( \*LOG, v => $verbose );
    isa_ok $smoker, 'Test::Smoke::Smoker';
    my @harness3_test = split m/\n/, <<'EOHO';
Failed 2/2 test programs. 83/100 subtests failed.
../t/smoke/die....... Dubious, test returned 255 (wstat 65280, 0xff00)
 No subtests run 
../t/smoke/many...... Dubious, test returned 83 (wstat 21248, 0x5300)
 Failed 83/100 subtests 

Test Summary Report
-------------------
smoke/die.t (Wstat: 65280 Tests: 0 Failed: 0)
  Non-zero exit status: 255
  Parse errors: No plan found in TAP output
smoke/many.t (Wstat: 21248 Tests: 100 Failed: 83)
  Failed test number(s):  2-6, 8-12, 14-18, 20-24, 26-30, 32-36, 38-42
                44-48, 50-54, 56-60, 62-66, 68-72, 74-78
                80-84, 86-90, 92-96, 98-100
  Non-zero exit status: 83
Files=2, Tests=100,  0 wallclock secs ( 0.03 usr  0.01 sys +  0.06 cusr  0.01 csys =  0.11 CPU)
Result: FAIL
EOHO

    my %inconsistent = map +( $_ => 1 ) => grep length $_ => map {
        m/(\S+\.t)\s+/ ? "../t/$1" : ''
    } @harness3_test;
    $inconsistent{ '../t/op/utftaint.t' } = 1;

    my $all_ok;
    my $harness_out = $smoker->_parse_harness_output( \%inconsistent, $all_ok,
                                                      @harness3_test );

    is $harness_out, <<EOOUT, "Catch Test::Harness 3+ output";
    ../t/smoke/die.t............................................FAILED
        No plan found in TAP output
    ../t/smoke/many.t...........................................FAILED
        2-6, 8-12, 14-18, 20-24, 26-30, 32-36, 38-42
        44-48, 50-54, 56-60, 62-66, 68-72, 74-78
        80-84, 86-90, 92-96, 98-100
EOOUT

    is keys %inconsistent, 1, "One inconssistent test result"
        or diag Dumper \%inconsistent;
}

{
    my $smoker = Test::Smoke::Smoker->new( \*LOG, v => $verbose );
    isa_ok $smoker, 'Test::Smoke::Smoker';
    my @harness3_test = split m/\n/, <<'EOHO';
Failed 2/2 test programs. 83/100 subtests failed.
../t/smoke/die....... Dubious, test returned 255 (wstat 65280, 0xff00)
 No subtests run 
../t/smoke/many...... Dubious, test returned 83 (wstat 21248, 0x5300)
 Failed 83/100 subtests 

Test Summary Report
-------------------
smoke/die (Wstat: 65280 Tests: 0 Failed: 0)
  Non-zero exit status: 255
  Parse errors: No plan found in TAP output
smoke/many (Wstat: 21248 Tests: 100 Failed: 83)
  Failed test number(s):  2-6, 8-12, 14-18, 20-24, 26-30, 32-36, 38-42
                44-48, 50-54, 56-60, 62-66, 68-72, 74-78
                80-84, 86-90, 92-96, 98-100
  Non-zero exit status: 83
Files=2, Tests=100,  0 wallclock secs ( 0.03 usr  0.01 sys +  0.06 cusr  0.01 csys =  0.11 CPU)
Result: FAIL
EOHO

    my %inconsistent = map +( $_ => 1 ) => grep length $_ => map {
        m/(\S+\.t)\s+/ ? "../t/$1" : ''
    } @harness3_test;
    $inconsistent{ '../t/op/utftaint.t' } = 1;

    my $all_ok;
    my $harness_out = $smoker->_parse_harness_output( \%inconsistent, $all_ok,
                                                      @harness3_test );

    is $harness_out, <<EOOUT, "Catch Test::Harness 3.13 output";
    ../t/smoke/die.t............................................FAILED
        No plan found in TAP output
    ../t/smoke/many.t...........................................FAILED
        2-6, 8-12, 14-18, 20-24, 26-30, 32-36, 38-42
        44-48, 50-54, 56-60, 62-66, 68-72, 74-78
        80-84, 86-90, 92-96, 98-100
EOOUT

    is keys %inconsistent, 1, "One inconssistent test result";
}

{ # test the set_skip_tests(), unset_skip_tests()
    my $src = catdir qw/ t ftppub perl-current /;
    my $dst = catdir qw/ t perl-current /;
    require_ok "Test::Smoke::Syncer";
    my $syncer = Test::Smoke::Syncer->new( copy => {
        v    => $verbose,
        cdir => $src,
        ddir => $dst,
    } );
    isa_ok $syncer, 'Test::Smoke::Syncer::Copy';
    my $patch = $syncer->sync;
    is $patch, '20000', "Patchlevel: $patch";

    my $skip_tests = catfile 't', 'MANIFEST.NOTEST';
    my %config = (
        v          => $verbose,
        ddir       => $dst,
        defaultenv => 1,
        testmake   => 'make',
        skip_tests => $skip_tests,
    );

    my $smoker = Test::Smoke::Smoker->new( \*LOG, %config );
    isa_ok( $smoker, 'Test::Smoke::Smoker' );

SKIP: {
    local *NOTESTS;
    open NOTESTS, "> $skip_tests" or skip "Cannot create($skip_tests): $!", 7;
    my @notest = qw{ t/op/skip.t lib/t/skip.t ext/t/skip.t };
    print NOTESTS "$_\n" for @notest;
    close NOTESTS;

    ok -f $skip_tests, "skip_tests file exists";

    $smoker->set_skip_tests;
    ok -f catfile( $dst, 'MANIFEST.ORG'), "MANIFEST was copied";

    ok ! -f catfile( $dst, 't', 'op', 'skip.t' ) &&
       -f catfile( $dst, 't', 'op', 'skip.tskip' ),
       "t/op/skip.t was renamed";

    my @libext = grep m{^(?:lib|ext)/} => @notest;
    my $manifest = catfile $dst, 'MANIFEST';
    my $manifiles = get_file( $manifest );

    my $ok = 1;
    $ok &&= ! grep $manifiles =~ /^\Q$_\E/m => @libext;
    ok $ok, "files removed from MANIFEST";

    $smoker->unset_skip_tests();

    ok ! -f catfile( $dst, 'MANIFEST.ORG'), "MANIFEST.ORG was removed";

    ok -f catfile( $dst, 't', 'op', 'skip.t' ) &&
       ! -f catfile( $dst, 't', 'op', 'skip.tskip' ),
       "t/op/skip.t was renamed back";

    my $files = get_file( $manifest );

    $ok = 1;
    $ok &&= grep $files =~ /^\Q$_\E/m => @libext;
    ok $ok, "files back in MANIFEST";

    1 while unlink $skip_tests;    
}
    rmtree $dst, $verbose;
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
