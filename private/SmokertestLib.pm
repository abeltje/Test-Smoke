package SmokertestLib;
use strict;

# $Id$
use vars qw( $VERSION @EXPORT );
$VERSION = '0.002';

use base 'Exporter';
@EXPORT = qw( &clean_mktest_stuff &make_report &get_report );

use File::Spec::Functions;

sub clean_mktest_stuff {
    my( $ddir ) = @_;
    return if exists $ENV{SMOKE_NO_CLEANUP} && $ENV{SMOKE_NO_CLEANUP};
    my $mktest_pat = catfile( $ddir, 'mktest.*' );
    system "rm -f $mktest_pat";
}

sub make_report {
    my( $ddir ) = @_;
    local @ARGV = ( 'nomail', $ddir );
    my $mkovz = catfile( $ddir, updir, updir, 'mkovz.pl' );

    # Calling mkovz.pl more than once gives redefine warnings:
    local $^W = 0;
    do $mkovz or do {
        warn "# Error '$mkovz': $@ [$!]";
        return undef;
    };
}

sub get_report {
    my( $ddir ) = @_;
    my $r_name = catfile( $ddir, 'mktest.rpt' );
    local *REPORT;
    open REPORT, "< $r_name" or return undef;
    my $report = do { local $/; <REPORT> };
    close REPORT;
    return $report;
}

1;
