#! /usr/bin/perl -w
use strict;

use File::Spec;
use FindBin;
use lib File::Spec->catdir( $FindBin::Bin );
use TestLib;

use Test::More tests => 16;

my $eg_config = { plevel => 19000, os => 'linux', osvers => '2.4.18-4g',
                  arch => 'i686/1 cpu', sum => 'PASS', version => '5.9.0' };

use_ok( 'Test::Smoke::Mailer' );
use Test::Smoke::Util 'parse_report_Config';

SKIP: {
    my $mhowto = 'mail';
    my $bin = whereis( $mhowto ) or skip "No '$mhowto' found", 5;
    write_report( $eg_config ) or skip "Cannot write report", 5;

    my $mailer = Test::Smoke::Mailer->new( $mhowto => {
        ddir => 't',
        mailbin => $bin,
    } );

    isa_ok( $mailer, 'Test::Smoke::Mailer' );
    isa_ok( $mailer, 'Test::Smoke::Mailer::Mail_X' );

    my $report = create_report( $eg_config );
    my $subject = $mailer->fetch_report();

    my @config = parse_report_Config( $mailer->{body} );
    my @conf = @{ $eg_config }{qw( version plevel os osvers arch sum )};
    
    is_deeply( \@config, \@conf, "Config..." );
    my $subj = sprintf "Smoke [%s] %s %s %s %s (%s)", @conf[0, 1, 5, 2, 3, 4];

    is( $subject, $subj, "Read the report: $subject" );
    is( $mailer->{body}, $report, "Report read back ok" );
    1 while unlink File::Spec->catfile( 't', 'mktest.rpt' );
}

SKIP: {
    my $mhowto = 'mailx';
    my $bin = whereis( $mhowto ) or skip "No '$mhowto' found", 5;
    write_report( $eg_config ) or skip "Cannot write report", 5;

    my $mailer = Test::Smoke::Mailer->new( $mhowto => {
        ddir => 't',
        mailbin => $bin,
    } );

    isa_ok( $mailer, 'Test::Smoke::Mailer' );
    isa_ok( $mailer, 'Test::Smoke::Mailer::Mail_X' );

    my $report = create_report( $eg_config );
    my $subject = $mailer->fetch_report();

    my @config = parse_report_Config( $mailer->{body} );
    my @conf = @{ $eg_config }{qw( version plevel os osvers arch sum )};
    
    is_deeply( \@config, \@conf, "Config..." );
    my $subj = sprintf "Smoke [%s] %s %s %s %s (%s)", @conf[0, 1, 5, 2, 3, 4];

    is( $subject, $subj, "Read the report: $subject" );
    is( $mailer->{body}, $report, "Report read back ok" );
    1 while unlink File::Spec->catfile( 't', 'mktest.rpt' );
}

SKIP: {
    local $ENV{PATH} = "$ENV{PATH}:/usr/sbin";
    my $mhowto = 'sendmail';
    my $bin = whereis( $mhowto ) or skip "No '$mhowto' found", 5;
    write_report( $eg_config ) or skip "Cannot write report", 5;

    my $mailer = Test::Smoke::Mailer->new( $mhowto => {
        ddir => 't',
        mailbin => $bin,
    } );

    isa_ok( $mailer, 'Test::Smoke::Mailer' );
    isa_ok( $mailer, 'Test::Smoke::Mailer::Sendmail' );

    my $report = create_report( $eg_config );
    my $subject = $mailer->fetch_report();

    my @config = parse_report_Config( $mailer->{body} );
    my @conf = @{ $eg_config }{qw( version plevel os osvers arch sum )};
    
    is_deeply( \@config, \@conf, "Config..." );
    my $subj = sprintf "Smoke [%s] %s %s %s %s (%s)", @conf[0, 1, 5, 2, 3, 4];

    is( $subject, $subj, "Read the report: $subject" );
    is( $mailer->{body}, $report, "Report read back ok" );
    1 while unlink File::Spec->catfile( 't', 'mktest.rpt' );
}

sub write_report {
    my $eg = shift;

    local *REPORT;
    my $report_file = File::Spec->catfile( 't', 'mktest.rpt' );

    my $report = create_report( $eg );

    open REPORT, "> $report_file" or return undef;
    print REPORT $report;
    close REPORT or return undef;

    return 1;
}

sub create_report {
    my $eg = shift;
    return "Automated smoke report for $eg->{version} patch " .
           "$eg->{plevel} on $eg->{os} - $eg->{osvers} ($eg->{arch})\n" .
           "\n\n\nStuff that goes here\nSummary: $eg->{sum}\n";
}
