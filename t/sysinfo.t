#! /usr/bin/perl -w
use strict;

# $Id$

use Test::More tests => 55;
my $verbose = 0;

my $findbin;
use File::Basename;
BEGIN { $findbin = dirname $0; }
use lib $findbin;
use TestLib;

BEGIN { use_ok "Test::Smoke::SysInfo", qw( sysinfo tsuname ) }

ok defined &sysinfo, "sysinfo() imported";
ok defined &tsuname, "tsuname() imported";

{
    local $^O = 'Generic';
    my $si = Test::Smoke::SysInfo->new;

    isa_ok $si => 'Test::Smoke::SysInfo';
    ok $si->cpu_type, $si->cpu_type;
    ok $si->cpu, $si->cpu;
    is $si->ncpu, '', "no ncpu";
    ok $si->os, $si->os;
    ok $si->host, $si->host;
}

{
    my $si = Test::Smoke::SysInfo->new;

    isa_ok $si => 'Test::Smoke::SysInfo';
    ok $si->cpu_type, "cpu_type: " . $si->cpu_type;
    ok $si->cpu,      "cpu: " . $si->cpu;
    SKIP: {
        $si->ncpu or skip "No #cpu code for this platform", 1;
        ok $si->ncpu,     "number of cpus: " . $si->ncpu
    }
    ok $si->os, $si->os;
    ok $si->host, $si->host;

    is join( " ", @{ $si }{map "_$_" => qw( host os cpu_type )} ),
       sysinfo(),
       "test sysinfo() " . sysinfo();
}

{
    my $si = Test::Smoke::SysInfo->new;
    isa_ok $si, 'Test::Smoke::SysInfo';

    my $tsuname = join " ", map $si->{ "_$_" } => qw(
        host os cpu ncpu cpu_type
    );
    is tsuname(), $tsuname,       "tsuname()";
    is tsuname(), tsuname( 'a' ), "tsuname(a)";
    is tsuname( 'rubbish' ), $tsuname, "tsuname( rubbish )";


    is tsuname( 'n' ), $si->{_host},     "tsuname(n)";
    is tsuname( 's' ), $si->{_os},       "tsuname(s)";
    is tsuname( 'm' ), $si->{_cpu},      "tsuname(m)";
    is tsuname( 'c' ), $si->{_ncpu},     "tsuname(c)";
    is tsuname( 'p' ), $si->{_cpu_type}, "tsuname(p)";

    is tsuname(qw( n s )), "$si->{_host} $si->{_os}", "tsuname(  n, s )";
    is tsuname(qw( n s )), tsuname( 'n s' ),          "tsuname( 'n s' )";
    is tsuname(qw( s n )), tsuname( 'n s' ),          "tsuname( 's n' )";

    is tsuname(qw( n m )), "$si->{_host} $si->{_cpu}", "tsuname(  n, m )";
    is tsuname(qw( n m )), tsuname( 'n m' ),           "tsuname( 'n m' )";
    is tsuname(qw( m n )), tsuname( 'n m' ),           "tsuname( 'm n' )";

    is tsuname(qw( n c )), "$si->{_host} $si->{_ncpu}", "tsuname(  n, c )";
    is tsuname(qw( n c )), tsuname( 'n c' ),            "tsuname( 'n c' )";
    is tsuname(qw( c n )), tsuname( 'n c' ),            "tsuname( 'c n' )";

    is tsuname(qw( n p )), "$si->{_host} $si->{_cpu_type}", "tsuname(  n, p )";
    is tsuname(qw( n p )), tsuname( 'n p' ),                "tsuname( 'n p' )";
    is tsuname(qw( p n )), tsuname( 'n p' ),                "tsuname( 'p n' )";

    is tsuname(qw( s m )), "$si->{_os} $si->{_cpu}", "tsuname(  s, m )";
    is tsuname(qw( s m )), tsuname( 's m' ),         "tsuname( 's m' )";
    is tsuname(qw( m s )), tsuname( 's m' ),         "tsuname( 'm s' )";

    is tsuname(qw( s c )), "$si->{_os} $si->{_ncpu}", "tsuname(  s, c )";
    is tsuname(qw( s c )), tsuname( 's c' ),          "tsuname( 's c' )";
    is tsuname(qw( c s )), tsuname( 's c' ),          "tsuname( 'c s' )";

    is tsuname(qw( s p )), "$si->{_os} $si->{_cpu_type}", "tsuname(  s, p )";
    is tsuname(qw( s p )), tsuname( 's p' ),              "tsuname( 's p' )";
    is tsuname(qw( p s )), tsuname( 's p' ),               "tsuname( 'p s' )";

    is tsuname(qw( m c )), "$si->{_cpu} $si->{_ncpu}", "tsuname(  m, c )";
    is tsuname(qw( m c )), tsuname( 'm c' ),           "tsuname( 'm c' )";
    is tsuname(qw( c m )), tsuname( 'm c' ),           "tsuname( 'c m' )";

    is tsuname(qw( m p )), "$si->{_cpu} $si->{_cpu_type}", "tsuname(  m, p )";
    is tsuname(qw( m p )), tsuname( 'm p' ),               "tsuname( 'm p' )";
    is tsuname(qw( p m )), tsuname( 'm p' ),               "tsuname( 'p m' )";

    is tsuname(qw( c p )), "$si->{_ncpu} $si->{_cpu_type}", "tsuname(  c, p )";
    is tsuname(qw( c p )), tsuname( 'c p' ),                "tsuname( 'c p' )";
    is tsuname(qw( p c )), tsuname( 'c p' ),                "tsuname( 'c p' )";
}
