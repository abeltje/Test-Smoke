#! /usr/bin/perl -w
use strict;
use Data::Dumper;

# $Id$

my $verbose = 0;
use Test::More tests => 30;

use_ok 'Test::Smoke::Reporter';

{
    my $reporter = Test::Smoke::Reporter->new( 
        v          => $verbose, 
        outfile    => '',
        defaultenv => 1,
    );
    isa_ok( $reporter, 'Test::Smoke::Reporter' );

    my $timer = time - 300;
    $reporter->read_parse( \(my $result = <<EORESULTS) );
Started smoke at @{ [$timer] }
Smoking patch 20000


Stopped smoke at @{ [$timer += 100] }
Started smoke at @{ [$timer] }

Configuration: -Dusedevel -Dcc='ccache gcc' -Uuseperlio
------------------------------------------------------------------------------
PERLIO = stdio  u=3.96  s=0.66  cu=298.11  cs=21.18  scripts=731  tests=75945
All tests successful.
Stopped smoke at @{ [$timer += 100] }
Started smoke at @{ [$timer] }

Configuration: -Dusedevel -Dcc='ccache gcc' -Uuseperlio -DDEBUGGING
------------------------------------------------------------------------------
PERLIO = stdio  u=4.43  s=0.76  cu=324.65  cs=21.58  scripts=731  tests=75945
All tests successful.
Finished smoking 20000
Stopped smoke at @{ [$timer += 100] }
EORESULTS

    is( $reporter->{_rpt}{started}, $timer - 300, "Start time" );
    is( $reporter->{_rpt}{patch}, 20000,
        "Changenumber $reporter->{_rpt}{patch}" );
    my $cfgarg = "-Dcc='ccache gcc' -Uuseperlio";
    is( $reporter->{_rpt}{$cfgarg}{N}{stdio}, "O",
        "'$cfgarg' reports ok" );
    is( $reporter->{_rpt}{$cfgarg}{D}{stdio}, "O",
        "'$cfgarg -DDEBUGGING' reports ok" );

    my @r_lines = split /\n/, $reporter->smoke_matrix;
    is_deeply \@r_lines, [split /\n/, <<__EOM__], "Matrix";
   20000     Configuration (common) -Dcc='ccache gcc'
----------- ---------------------------------------------------------
O O         -Uuseperlio
__EOM__

#    diag Dumper $reporter->{_counters};
#    diag $reporter->report;
}

{
    my $reporter = Test::Smoke::Reporter->new( 
        v       => $verbose, 
        outfile => '',
    );
    isa_ok( $reporter, 'Test::Smoke::Reporter' );

    my $timer = time - 1000;
    my $patchlevel = 21000;
    $reporter->read_parse( \(my $result = <<EORESULTS) );
Started smoke at @{ [$timer] }
Smoking patch $patchlevel

MANIFEST did not declare t/perl

Stopped smoke at @{ [$timer += 100] }
Started smoke at @{ [$timer] }

Configuration: -Dusedevel -Dcc='ccache gcc'
------------------------------------------------------------------------------
TSTENV = stdio  u=3.93  s=0.60  cu=262.21  cs=27.41  scripts=764  tests=76593

    ../lib/Benchmark.t............FAILED 193

TSTENV = perlio u=3.66  s=0.50  cu=233.24  cs=24.79  scripts=764  tests=76593
All tests successful.
TSTENV = locale:nl_NL.utf8      u=3.90  s=0.54  cu=256.36  cs=26.99  scripts=763  tests=7658

    ../lib/Benchmark.t............FAILED 193

Stopped smoke at @{ [$timer += 100] }
Started smoke at @{ [$timer] }

Configuration: -Dusedevel -Dcc='ccache gcc' -DDEBUGGING
------------------------------------------------------------------------------
TSTENV = stdio  u=3.98  s=0.60  cu=276.95  cs=27.43  scripts=764  tests=76593

    ../lib/Benchmark.t............FAILED 193

TSTENV = perlio u=3.66  s=0.57  cu=262.38  cs=25.93  scripts=764  tests=76593
All tests successful.
TSTENV = locale:nl_NL.utf8      u=4.15  s=0.62  cu=269.53  cs=27.02  scripts=763  tests=7658
7

    ../lib/Benchmark.t............FAILED 193

Finished smoking $patchlevel
Stopped smoke at @{ [$timer += 100] }
EORESULTS

    is( $reporter->{_rpt}{patch}, $patchlevel,
        "Changenumber $reporter->{_rpt}{patch}" );

    my $cfgarg = "-Dcc='ccache gcc'";
    {   local $" = "', '";
        my @bldenv = sort keys %{ $reporter->{_rpt}{$cfgarg}{N} };
        is_deeply( \@bldenv, [qw( locale:nl_NL.utf8 perlio stdio )],
                   "Buildenvironments '@bldenv'" );
    }

    is( $reporter->{_rpt}{$cfgarg}{N}{stdio}, 'F',
        "'$cfgarg' (stdio) reports failure" );
    is( $reporter->{_rpt}{$cfgarg}{D}{stdio}, 'F',
        "'$cfgarg -DDEBUGGING' (stdio) reports failure" );

    is( $reporter->{_rpt}{$cfgarg}{N}{perlio}, 'O',
        "'$cfgarg' (perlio) reports OK" );
    is( $reporter->{_rpt}{$cfgarg}{D}{perlio}, 'O',
        "'$cfgarg -DDEBUGGING' (perlio) reports OK" );

    is( $reporter->{_rpt}{$cfgarg}{N}{'locale:nl_NL.utf8'}, 'F',
        "'$cfgarg' (utf8) reports failure" );
    is( $reporter->{_rpt}{$cfgarg}{D}{'locale:nl_NL.utf8'}, 'F',
        "'$cfgarg -DDEBUGGING' (utf8) reports Failure" );

    my @r_lines = split /\n/, $reporter->smoke_matrix;
    is_deeply \@r_lines, [split /\n/, <<__EOM__], "Matrix";
   21000     Configuration (common) -Dcc='ccache gcc'
----------- ---------------------------------------------------------
F O F F O F 
__EOM__

#    diag Dumper $reporter->{_counters};
#    diag $reporter->report;
}

{
    my $reporter = Test::Smoke::Reporter->new( 
        v       => $verbose, 
        outfile => '',
    );
    isa_ok( $reporter, 'Test::Smoke::Reporter' );

    my $patchlevel = 19000;
    $reporter->read_parse( \(my $result = <<EORESULTS) );
Smoking patch 19000
Stopped smoke at 1073290464
Started smoke at 1073290464

Configuration: -Dusedevel
------------------------------------------------------------------------------
PERLIO = stdio  u=0.05  s=0  cu=0.26  cs=0  scripts=4  tests=107
All tests successful.
PERLIO = perlio u=0.03  s=0.01  cu=0.24  cs=0.04  scripts=4  tests=107
All tests successful.
Stopped smoke at 1073290465
Started smoke at 1073290465

Configuration: -Dusedevel -DDEBUGGING
------------------------------------------------------------------------------
PERLIO = stdio  u=0.04  s=0.01  cu=0.26  cs=0.02  scripts=3  tests=106

    ../t/smoke/die.t........................FAILED ??
    ../t/smoke/many.t.......................FAILED 2-6 8-12 14-18 20-24 26-30 32
                                         36 38-42 44-48 50-54 56-60 62
                                         66 68-72 74-78 80-84 86-90 92
                                         96 98-100

PERLIO = perlio u=0.05  s=0.01  cu=0.25  cs=0.02  scripts=3  tests=106

    ../t/smoke/die.t........................FAILED ??
    ../t/smoke/many.t.......................FAILED 2-6 8-12 14-18 20-24 26-30 32
                                         36 38-42 44-48 50-54 56-60 62
                                         66 68-72 74-78 80-84 86-90 92
                                         96 98-100

Stopped smoke at 1073290467
EORESULTS

    is( $reporter->{_rpt}{patch}, $patchlevel,
        "Changenumber $reporter->{_rpt}{patch}" );

    my $cfgarg = "";
    {   local $" = "', '";
        my @bldenv = sort keys %{ $reporter->{_rpt}{$cfgarg}{N} };
        is_deeply( \@bldenv, [qw( perlio stdio )],
                   "Buildenvironments '@bldenv'" );
        @bldenv = sort @{ $reporter->{_tstenv} };
        is_deeply( \@bldenv, [qw( perlio stdio )],
                   "Buildenvironments '@bldenv'" );
    }

    is( $reporter->{_rpt}{$cfgarg}{N}{stdio}, 'O',
        "'$cfgarg' (stdio) reports OK" );
    is( $reporter->{_rpt}{$cfgarg}{D}{stdio}, 'F',
        "'$cfgarg -DDEBUGGING' (stdio) reports failure" );

    is( $reporter->{_rpt}{$cfgarg}{N}{perlio}, 'O',
        "'$cfgarg' (perlio) reports OK" );
    is( $reporter->{_rpt}{$cfgarg}{D}{perlio}, 'F',
        "'$cfgarg -DDEBUGGING' (perlio) reports Failure" );

    my @r_lines = split /\n/, $reporter->smoke_matrix;
    is_deeply \@r_lines, [split /\n/, <<__EOM__], "Matrix";
   19000     Configuration (common) none
----------- ---------------------------------------------------------
O O F F     
__EOM__

    like $reporter->report, 
         '/^Failures:\n\[stdio\/perlio\]\s* -DDEBUGGING/m',
         "Failures:";
}

{ # This test is just to test 'PASS' (and not PASS-so-far)
    my $reporter = Test::Smoke::Reporter->new( 
        v       => $verbose, 
        outfile => '',
    );
    my $patchlevel = 22111;

    isa_ok $reporter, 'Test::Smoke::Reporter';
    $reporter->read_parse( \(my $result = <<EORESULTS) );
Started smoke at 1073864611
Smoking patch 22111
Stopped smoke at 1073864615
Started smoke at 1073864615

Configuration: -Dusedevel -Dcc='ccache egcc' -Uuseperlio
------------------------------------------------------------------------------

Compiler info: ccache egcc version 3.2
TSTENV = stdio  u=8.42  s=2.10  cu=476.05  cs=61.49  scripts=776  tests=78557
All tests successful.
Stopped smoke at 1073866466
Started smoke at 1073866466

Configuration: -Dusedevel -Dcc='ccache egcc' -Uuseperlio -DDEBUGGING
------------------------------------------------------------------------------

Compiler info: ccache egcc version 3.2
TSTENV = stdio  u=9.84  s=2.03  cu=523.95  cs=61.85  scripts=776  tests=78557
All tests successful.
Finished smoking 22111
Stopped smoke at 1073869001
EORESULTS

    my $report = $reporter->report;
    is $reporter->{_rpt}{patch}, $patchlevel, "Patchlevel $patchlevel";
    like $report, "/^Summary: PASS\n/m", 
         "Report PASS for -Uuseperlio";

}
