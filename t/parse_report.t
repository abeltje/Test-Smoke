#! /usr/bin/perl -w
use strict;

# $Id$

use Test::More tests => 6;

my @eg = (
    { plevel => 19000, os => 'linux', osvers => '2.4.18-4g',
      arch => 'i686/1 cpu', sum => 'PASS', version => '5.9.0' },
    { plevel => 19001, os => 'MSWin32', osvers => '5.',
      arch => 'x86/1 cpu', sum => 'PASS', version => '5.9.0' },
    { plevel => 19002, os => 'aix', osvers => '4.3.1.0',
      arch => 'aix/8 cpus', sum => 'PASS', version => '5.9.0' },
    { plevel => 19003, os => 'linux', osvers => '2.4.20-1jv.7.x',
      arch => 'i686/1 cpu', sum => 'PASS', version => '5.9.0' },
    { plevel => 19004, os => 'dec_osf', osvers => '5.1a',
      arch => 'alpha/1 cpu', sum => 'FAIL(F)', version => '5.9.0' },
);

BEGIN { use_ok( 'Test::Smoke::Util', 'parse_report_Config' ); }

foreach my $eg ( @eg ) {
    my $report = "Automated smoke report for $eg->{version} patch " .
                 "$eg->{plevel} on $eg->{os} - $eg->{osvers} ($eg->{arch})\n" .
                 "\n\n\nStuff that goes here\nSummary: $eg->{sum}\n";

    my %conf;

    @conf{qw( version plevel os osvers arch sum ) } = 
        parse_report_Config( $report );

    my $subject = "Smoke [$eg->{version}] $eg->{plevel} $eg->{sum} $eg->{os}" .
                  " $eg->{osvers} ($eg->{arch})";
    is_deeply( \%conf, $eg, $subject );
}
