package SmokertestLib;
use strict;

# $Id$
use vars qw( $VERSION @EXPORT );
$VERSION = '0.004';

use base 'Exporter';
@EXPORT = qw( 
    &clean_mktest_stuff
    &make_report &get_report
    &get_Win32_args
);

use File::Spec::Functions;

sub clean_mktest_stuff {
    my( $ddir ) = @_;
    return if exists $ENV{SMOKE_NO_CLEANUP} && $ENV{SMOKE_NO_CLEANUP};
    my $mktest_pat = catfile( $ddir, 'mktest.*' );
    system "rm -f $mktest_pat";
}

sub make_report {
    use Test::Smoke::Reporter;
    my( $ddir ) = @_;
    my $reporter = Test::Smoke::Reporter->new( ddir => $ddir );
    my $report = $reporter->report;
    local *RPT;
    my $rptname = File::Spec->catfile( $ddir, 'mktest.rpt' );
    if ( open RPT, "> $rptname" ) {
        print RPT $report;
        close RPT or warn "Error writing '$rptname': $!\n";
    } else {
#        warn "Error creating '$rptname': $!\n$report\n";
         return undef
    }
    return 1;
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

sub get_Win32_args {
    my %w32args  = ( w32cct => "", is_win32 => 0 );
    if ( $^O eq 'MSWin32' ) {
        my $w32make = exists $ENV{SMOKE_W32MAKE} 
            ? $ENV{SMOKE_W32MAKE} : 'dmake';
        $w32make ||= 'dmake';
        my $w32cc = exists $ENV{SMOKE_W32CC} 
            ? $ENV{SMOKE_W32CC} : "GCC";
        $w32cc ||= "GCC";
        %w32args = (
            is_win32 => 1,
            w32cc    => $w32cc,
            w32cct   => "-DCCTYPE=$w32cc",
            w32make  => $w32make,
        );
    }
    return %w32args;
}

1;
