#! /usr/bin/perl -w
use strict;
$| = 1;

# $Id$

use File::Spec::Functions;
my $findbin;
use File::Basename;
BEGIN { $findbin = dirname $0; }
use lib $findbin;
use TestLib;

my $verbose = exists $ENV{SMOKE_VERBOSE} ? $ENV{SMOKE_VERBOSE} : 0;
my $showcfg = 0;

use Test::More tests => 53;

use_ok 'Test::Smoke::Reporter';

my $config_sh = catfile( $findbin, 'config.sh' );
{
    create_config_sh( $config_sh, version => '5.6.1' );
    my $reporter = Test::Smoke::Reporter->new(
        ddir       => $findbin,
        v          => $verbose, 
        outfile    => '',
        showcfg    => $showcfg,
        cfg        => \( my $bcfg = <<__EOCFG__ ),
-Dcc='ccache gcc'
=
-Uuseperlio
__EOCFG__
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

    chomp( my $summary = $reporter->summary );
    is $summary, 'Summary: PASS', $summary;
    unlike $reporter->report, "/Build configurations:\n$bcfg=/", 
            "hasn't the configurations";

#    diag Dumper $reporter->{_counters};
#    diag $reporter->report;
}

{
    create_config_sh( $config_sh, version => '5.8.3' );
    my $reporter = Test::Smoke::Reporter->new(
        ddir    => $findbin,
        v       => $verbose, 
        outfile => '',
        showcfg => $showcfg,
        cfg     => \( my $bcfg = <<__EOCFG__ ),
-Dcc='ccache gcc'
__EOCFG__
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

    chomp( my $summary = $reporter->summary );
    is $summary, 'Summary: FAIL(F)', $summary;
    if ( $showcfg ) {
         like $reporter->report, "/Build configurations:\n$bcfg=/", 
              "has the configurations";
    } else {
         unlike $reporter->report, "/Build configurations:\n$bcfg=/", 
                "hasn't the configurations";
    }

#    diag Dumper $reporter->{_counters};
#    diag $reporter->report;
}

{
    create_config_sh( $config_sh, version => '5.9.0' );
    my $reporter = Test::Smoke::Reporter->new(
        ddir    => $findbin,
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

    chomp( my $summary = $reporter->summary );
    is $summary, 'Summary: FAIL(F)', $summary;
    like $reporter->report, qq@/^
         Failures: \\s+ \\(common-args\\) \\s+ none \\n
         \\[stdio\\/perlio\\] \\s* -DDEBUGGING
    /xm@, "Failures:";
}

unlink $config_sh;

{ # This test is just to test 'PASS' (and not PASS-so-far)
#    create_config_sh( $config_sh, version => '5.00504' );
    my $reporter = Test::Smoke::Reporter->new( 
        ddir    => $findbin,
        v       => $verbose, 
        outfile => '',
        is56x   => 1,
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

    chomp( my $summary = $reporter->summary );
    is $summary, 'Summary: PASS', $summary;
    is $reporter->ccinfo, "ccache egcc version 3.2", "ccinfo()";
    like $reporter->report, "/^Summary: PASS\n/m", "Summary from report";

    my @r_lines = split /\n/, $reporter->smoke_matrix;
    is_deeply \@r_lines, [split /\n/, <<__EOM__], "Matrix";
   22111     Configuration (common) -Dcc='ccache egcc'
----------- ---------------------------------------------------------
O O         -Uuseperlio
__EOM__

}

{ # Test a bug reported by Merijn
  # the c's were reported for locale: only
    ok( my $reporter = Test::Smoke::Reporter->new(
        ddir       => catfile( $findbin, 'ftppub' ),
        is56x      => 0,
        defaultenv => 0,
        locale     => 'EN_US.UTF-8',
        outfile    => 'bugtst01.out',
        v          => $verbose,
        showcfg    => $showcfg,
        cfg        => \( my $bcfg = <<__EOCFG__ ),
-Dcc=gcc
=

-Duselongdouble
-Duse564bitint
__EOCFG__
    ), "new()" );
    isa_ok $reporter, 'Test::Smoke::Reporter';
    is $reporter->ccinfo, "? unknown cc version ", "ccinfo(bugstst01)";

    my @r_lines = split /\n/, $reporter->smoke_matrix;
    my $r = is_deeply \@r_lines, [split /\n/, <<__EOM__], "Matrix";
   22154     Configuration (common) -Dcc=gcc
----------- ---------------------------------------------------------
F F F F F F 
c - - c - - -Duselongdouble
F F F - - - -Duse64bitint
__EOM__

    $r or diag $reporter->smoke_matrix, $reporter->bldenv_legend;

    if ( $showcfg ) {
         like $reporter->report, "/Build configurations:\n$bcfg=/", 
              "has the configurations";
    } else {
         unlike $reporter->report, "/Build configurations:\n$bcfg=/", 
                "hasn't the configurations";
    }
}

{ # report from cygwin
    ok( my $reporter = Test::Smoke::Reporter->new(
        ddir       => catdir( $findbin, 'ftppub' ),
        is56x      => 0,
        defaultenv => 0,
        outfile    => 'bugtst02.out',
        v          => $verbose,
        showcfg    => $showcfg,
        cfg        => \( my $bcfg = <<__EOCFG__ ),

-Duseithreads
=

-Duse64bitint
__EOCFG__
    ), "new reporter for bugtst02.out" );
    isa_ok $reporter, 'Test::Smoke::Reporter';
    is $reporter->ccinfo, "gcc version 3.3.1 (cygming special)", 
       "ccinfo(bugstst02)";

    my @r_lines = split /\n/, $reporter->smoke_matrix;
    my $r = is_deeply \@r_lines, [split /\n/, <<__EOM__], "Matrix 2";
   22302     Configuration (common) none
----------- ---------------------------------------------------------
F F M -     
F F M -     -Duse64bitint
F F M -     -Duseithreads
F F M -     -Duseithreads -Duse64bitint
__EOM__

    $r or diag $reporter->smoke_matrix, $reporter->bldenv_legend;

    if ( $showcfg ) {
         like $reporter->report, "/Build configurations:\n$bcfg=/", 
              "has the configurations";
    } else {
         unlike $reporter->report, "/Build configurations:\n$bcfg=/", 
                "hasn't the configurations";
    }
}

{ # report from Win32
    ok( my $reporter = Test::Smoke::Reporter->new(
        ddir       => catdir( $findbin, 'ftppub' ),
        is56x      => 0,
        defaultenv => 1,
        is_win32   => 1,
        outfile    => 'bugtst03.out',
        v          => $verbose,
        showcfg    => $showcfg,
        cfg        => \( my $bcfg = <<'__EOCFG__' ),
-DINST_TOP=$(INST_DRV)\Smoke\doesntexist
=

-Duseithreads
=

-Duselargefiles
=

-Dusemymalloc
=

-Accflags='-DPERL_COPY_ON_WRITE'
=

-DDEBUGGING
__EOCFG__
    ), "new reporter for bugtst03.out" );
    isa_ok $reporter, 'Test::Smoke::Reporter';
    is $reporter->ccinfo, "cl version 12.00.8804",
       "ccinfo(bugstst03)";

    my @r_lines = split /\n/, $reporter->smoke_matrix;
    my $r = is_deeply \@r_lines, [split /\n/, <<'__EOM__'], "Matrix 3";
   22423     Configuration (common) -DINST_TOP=$(INST_DRV)\Smoke\doesntexist
----------- ---------------------------------------------------------
O O         
F F         -Accflags='-DPERL_COPY_ON_WRITE'
O O         -Dusemymalloc
F F         -Dusemymalloc -Accflags='-DPERL_COPY_ON_WRITE'
O O         -Duselargefiles
F F         -Duselargefiles -Accflags='-DPERL_COPY_ON_WRITE'
O O         -Duselargefiles -Dusemymalloc
F F         -Duselargefiles -Dusemymalloc -Accflags='-DPERL_COPY_ON_WRITE'
X O         -Duseithreads
F F         -Duseithreads -Accflags='-DPERL_COPY_ON_WRITE'
O O         -Duseithreads -Dusemymalloc
F F         -Duseithreads -Dusemymalloc -Accflags='-DPERL_COPY_ON_WRITE'
X O         -Duseithreads -Duselargefiles
F F         -Duseithreads -Duselargefiles -Accflags='-DPERL_COPY_ON_WRITE'
X O         -Duseithreads -Duselargefiles -Dusemymalloc
F F         -Duseithreads -Duselargefiles -Dusemymalloc -Accflags='-DPERL_COPY_ON_WRITE'
__EOM__

    $r or diag $reporter->smoke_matrix, $reporter->bldenv_legend;

    if ( $showcfg ) {
         like $reporter->report, "/Build configurations:\n$bcfg=/", 
              "has the configurations";
    } else {
         unlike $reporter->report, "/Build configurations:\n$bcfg=/", 
                "hasn't the configurations";
    }
    my @f_lines = split /\n/, $reporter->failures;
    is_deeply \@f_lines, [split /\n/, <<'__EOFAIL__'], "Failures(bugtst03)";
[default] -Accflags='-DPERL_COPY_ON_WRITE'
[default] -Dusemymalloc -Accflags='-DPERL_COPY_ON_WRITE'
[default] -Duselargefiles -Accflags='-DPERL_COPY_ON_WRITE'
[default] -Duselargefiles -Dusemymalloc -Accflags='-DPERL_COPY_ON_WRITE'
    ../ext/Cwd/t/cwd.t......................FAILED 10 12 14 16-18
    op/magic.t..............................FAILED 37-53
    op/tie.t................................FAILED 22

[default] -DDEBUGGING -Accflags='-DPERL_COPY_ON_WRITE'
[default] -DDEBUGGING -Duselargefiles -Accflags='-DPERL_COPY_ON_WRITE'
    ../ext/Cwd/t/cwd.t......................FAILED 9-20
    op/magic.t..............................FAILED 37-53
    op/tie.t................................FAILED 22

[default] -DDEBUGGING -Dusemymalloc -Accflags='-DPERL_COPY_ON_WRITE'
[default] -DDEBUGGING -Duselargefiles -Dusemymalloc -Accflags='-DPERL_COPY_ON_WRITE'
    ../ext/Cwd/t/cwd.t......................FAILED 9-20
    ../lib/DBM_Filter/t/utf8.t..............FAILED 13 19
    op/magic.t..............................FAILED 37-53
    op/tie.t................................FAILED 22

[default] -Duseithreads
Inconsistent test results (between TEST and harness):
    ../ext/threads/t/thread.t...............FAILED test 25

[default] -Duseithreads -Accflags='-DPERL_COPY_ON_WRITE'
[default] -Duseithreads -Dusemymalloc -Accflags='-DPERL_COPY_ON_WRITE'
    ../ext/Cwd/t/cwd.t......................FAILED 18-20

[default] -DDEBUGGING -Duseithreads -Accflags='-DPERL_COPY_ON_WRITE'
[default] -DDEBUGGING -Duseithreads -Dusemymalloc -Accflags='-DPERL_COPY_ON_WRITE'
[default] -DDEBUGGING -Duseithreads -Duselargefiles -Accflags='-DPERL_COPY_ON_WRITE'
[default] -DDEBUGGING -Duseithreads -Duselargefiles -Dusemymalloc -Accflags='-DPERL_COPY_ON_WRITE'
    ../ext/Cwd/t/cwd.t......................FAILED 9-20

[default] -Duseithreads -Duselargefiles
[default] -Duseithreads -Duselargefiles -Dusemymalloc
Inconsistent test results (between TEST and harness):
    ../ext/threads/t/problems.t.............dubious

[default] -Duseithreads -Duselargefiles -Accflags='-DPERL_COPY_ON_WRITE'
[default] -Duseithreads -Duselargefiles -Dusemymalloc -Accflags='-DPERL_COPY_ON_WRITE'
    ../ext/Cwd/t/cwd.t......................FAILED 18-20
Inconsistent test results (between TEST and harness):
    ../ext/threads/shared/t/sv_simple.t.....dubious
__EOFAIL__

}

sub create_config_sh {
    my( $file, %cfg ) = @_;

    my $cfg_sh = "# This is a testfile config.sh\n";
    $cfg_sh   .= "# created by $0\n";

    $cfg_sh   .= join "", map "$_='$cfg{$_}'\n" => keys %cfg;

    put_file( $cfg_sh, $file );
}
