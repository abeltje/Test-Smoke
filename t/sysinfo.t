#! /usr/bin/perl -w
use strict;

# $Id$

use Test::More tests => 15;
my $verbose = 0;

use FindBin;
use lib $FindBin::Bin;
use TestLib;

BEGIN { use_ok "Test::Smoke::SysInfo", "sysinfo" }

ok defined &sysinfo, "sysinfo() imported";

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
    ok $si->ncpu,     "number of cpus: " . $si->ncpu;
    ok $si->os, $si->os;
    ok $si->host, $si->host;

    is join( " ", map $si->$_ => qw( host os cpu_type ) ), sysinfo(),
       "test sysinfo() " . sysinfo();
}
