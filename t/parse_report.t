#! /usr/bin/perl -w
use strict;

# $Id$

use Test::More tests => 7;

my @eg = (
    { plevel => 19000, os => 'linux', osvers => '2.4.18-4g',
      arch => 'i686/1 cpu', sum => 'PASS', version => '5.00504' },
    { plevel => 19001, os => 'MSWin32', osvers => '5.',
      arch => 'x86/1 cpu', sum => 'PASS', version => '5.9.0' },
    { plevel => 19002, os => 'aix', osvers => '4.3.1.0',
      arch => 'PPC_64/8 cpus', sum => 'PASS', version => '5.9.0' },
    { plevel => 19003, os => 'linux', osvers => '2.4.20-1jv.7.x',
      arch => 'i686/1 cpu', sum => 'PASS', version => '5.9.0' },
    { plevel => 19004, os => 'dec_osf', osvers => '5.1a',
      arch => 'alpha/1 cpu', sum => 'FAIL(F)', version => '5.9.0' },
    { plevel => 19005, os => 'linux', osvers => '2.4.23-sparc-r1 [gentoo]',
      arch => 'sparc64/1 cpu', sum => 'FAIL(F)', version => '5.8.3' },
);

BEGIN { use_ok( 'Test::Smoke::Util', 'parse_report_Config' ); }

foreach my $eg ( @eg ) {
    my $report = <<__EOR__;
Automated smoke report for $eg->{version} patch $eg->{plevel}
host: A very long(R) archstring(C) (999MHZ) ($eg->{arch})
    on        $eg->{os} - $eg->{osvers}
    using     cc version 4.2
    smoketime 42 minutes 42 seconds

Summary: $eg->{sum}
__EOR__

    my %conf;

    @conf{qw( version plevel os osvers arch sum ) } = 
        parse_report_Config( $report );

    my $subject = "Smoke [$eg->{version}] $eg->{plevel} $eg->{sum} $eg->{os}" .
                  " $eg->{osvers} ($eg->{arch})";
    is_deeply( \%conf, $eg, $subject );
}
