#! /usr/bin/perl -w
use strict;
$| = 1;

# $Id$
use vars qw( $VERSION );
$VERSION = '0.002';

use Cwd;
use File::Spec;
use File::Path;
use File::Copy;
use FindBin;
use lib File::Spec->catdir( $FindBin::Bin, 'lib' );
use lib $FindBin::Bin;
use Test::Smoke;
use Test::Smoke::Util qw( get_patch do_pod2usage );

my $myusage = "Usage: $0 -c [smokeconfig]";
use Getopt::Long;
my %opt = (
    ddir    => undef,
    cfg     => undef,

    config  => undef,
    help    => 0,
    man     => 0,
);

=head1 NAME

smokestatus.pl - Check the status of a running smoke

=head1 SYNOPSIS

    $ ./smokestatus.pl -c [smokecurrent_config]

=head1 OPTIONS

=over 4

=item * B<Configuration file>

    -c | --config <configfile> Use the settings from the configfile

F<patchtree.pl> can use the configuration file created by F<configsmoke.pl>.
Other options can override the settings from the configuration file.

=item * B<General options>

    -d | --ddir <directory>  Set the directory for the source-tree (cwd)
    --cfg <buildconfig>      Set the buildconfig file

    -h | --help              Show help message (needs Pod::Usage)
    --man                    Show the perldoc  (needs Pod::Usage)

=back

=head1 DESCRIPTION

This is a small program that checks the status of a running smoke and
reports.

=cut

GetOptions( \%opt,
    'ddir|d=s', 'cfg=s',

    'help|h', 'man',

    'config|c:s',
) or do_pod2usage( verbose => 1, myusage => $myusage );

$opt{ man} and do_pod2usage( verbose => 2, exitval => 0, myusage => $myusage );
$opt{help} and do_pod2usage( verbose => 1, exitval => 0, myusage => $myusage );

if ( defined $opt{config} ) {
    $opt{config} eq "" and $opt{config} = 'smokecurrent_config';
    read_config( $opt{config} ) or do {
        my $config_name = File::Spec->catfile( $FindBin::Bin, $opt{config} );
        read_config( $config_name );
    };

    unless ( Test::Smoke->config_error ) {
        foreach my $option ( keys %opt ) {
            next if defined $opt{ $option };
            if ( $option eq 'type' ) {
                $opt{type} ||= $conf->{patch_type};
            } elsif ( exists $conf->{ $option } ) {
                $opt{ $option } ||= $conf->{ $option }
            }
        }
    } else {
        warn "WARNING: Could not process '$opt{config}': " . 
             Test::Smoke->config_error . "\n";
    }
}

my $rpt  = parse_out( $opt{ddir} );
my $bcfg = Test::Smoke::BuildCFG->new( $conf->{cfg} );
my $ccnt = 0;
Test::Smoke::skip_config( $_ ) or $ccnt++ for $bcfg->configurations;

printf "Change number $rpt->{patch} started on %s GMT.\n", 
       scalar gmtime( $rpt->{started} );

print "$rpt->{count} out of $ccnt configurations finished",
       $rpt->{count} ? " in $rpt->{time}.\n" : ".\n";

printf "$rpt->{fail} configuration%s showed failures%s.\n",
       ($rpt->{fail} == 1 ? "" : "s"), $rpt->{stat} ? " ($rpt->{stat})" : ""
    if $rpt->{count};

printf "$rpt->{running} failure%s in the running configuration.\n",
       ($rpt->{running} == 1 ? "" : "s")
    if exists $rpt->{running};

my $todo = $ccnt - $rpt->{count};
my $todo_time = $rpt->{avg} eq 'unknown' ? '.' :
       ", estimated completion in " . time_in_hhmm( $todo * $rpt->{avg} );
printf "$todo configuration%s to finish$todo_time\n",
       $todo == 1 ? "" : "s"
    if $todo;

sub parse_out {
    my( $ddir ) = @_;
    my $mktest_out = File::Spec->catfile( $ddir, 'mktest.out' );
    local *MKTESTOUT;
    open MKTESTOUT, "< $mktest_out" or die "Cannot open '$mktest_out': $!";
    my( %rpt, $cfg, $cnt, $start );
    while ( <MKTESTOUT> ) {
        m/^\s*$/ and next;
        m/^-+$/  and next;
        s/\s*$//;

        next if /^MANIFEST/ || /^PERLIO\s*=/ ||
                /^Skipped this configuration/;

        if  ( my( $patch ) = /^Smoking patch\s* (\d+\S*)/ ) {
            $rpt{patch} = $patch;
            next;
        }

        if ( my( $status, $time ) = /(Started|Stopped) smoke at (\d+)/ ) {
            if ( $status eq "Started" ) {
                $start = $time;
                $rpt{started} ||= $time;
            } else {
                $rpt{secs} += ($time - $start) if defined $start;
            }
            next;
        }

        if ( s/^\s*Configuration:\s*// ) {
            $rpt{config}->{ $cfg } = $cnt if defined $cfg;
            $cfg = $_; $cnt = 0;
            next;
        }

        if ( /^Finished smoking \d+/ ) {
            $rpt{config}{ $cfg } = $cnt;
            $rpt{finished} = "Finished";
            next;
        }

        if ( my( $status, $mini ) = 
             m/^\s*Unable\ to
               \ (?=([cbmt]))(?:build|configure|make|test)
               \ (anything\ but\ mini)?perl/x) {
            $mini and $status = uc $status; # M for no perl but miniperl
            $cnt = $status;
            next;
        }
        $cnt = 0, next if /^\s*All tests successful/;
        $cnt++,   next if /FAILED|DIED/;
	next;
    }
    close MKTESTOUT;

    $rpt{finished} ||= "Busy";
    $rpt{count} = scalar keys %{ $rpt{config} };
    $rpt{avg}   = $rpt{count} ? $rpt{secs} / $rpt{count} : 'unknown';
    $rpt{time}  = time_in_hhmm( $rpt{secs} );
    $rpt{fail} = 0; $rpt{stat} = { };
    foreach my $config ( keys %{ $rpt{config} } ) {

        if ( $rpt{config}{ $config } ) {
            $rpt{config}{ $config } = "F" 
                if $rpt{config}{ $config } =~ /^\d+$/;

            $rpt{fail}++;
            $rpt{stat}->{ $rpt{config}{ $config } }++;
        }
    }
    $rpt{stat} = join "", sort keys %{ $rpt{stat} };

    $rpt{running} = $cnt unless exists $rpt{config}->{ $cfg };

    return \%rpt    
}

sub time_in_hhmm {
    my $diff = shift;

    my $digits = $diff =~ /\./ ? 3 : 0;
    my $days = int( $diff / (24*60*60) );
    $diff -= 24*60*60 * $days;
    my $hour = int( $diff / (60*60) );
    $diff -= 60*60 * $hour;
    my $mins = int( $diff / 60 );
    $diff -=  60 * $mins;

    my @parts;
    $days and push @parts, sprintf "%d day%s",   $days, $days == 1 ? "" : 's';
    $hour and push @parts, sprintf "%d hour%s",  $hour, $hour == 1 ? "" : 's';
    $mins and push @parts, sprintf "%d minute%s",$mins, $mins == 1 ? "" : 's';
    $diff && !$days && !$hour and
        push @parts, sprintf "%.${digits}f seconds", $diff;

    return join " ", @parts;
}

=head1 COPYRIGHT

(c) 2002-2003, All rights reserved.

  * Abe Timmerman <abeltje@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See:

=over 4

item * L<http://www.perl.com/perl/misc/Artistic.html>

item * L<http://www.gnu.org/copyleft/gpl.html>

=back

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
