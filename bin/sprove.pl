#! /usr/bin/perl -w
use strict;

# $Id$
use vars qw( $VERSION );
$VERSION = '0.001';

use File::Spec;
use FindBin;
use lib File::Spec->catdir( $FindBin::Bin, 'lib' );
use lib $FindBin::Bin;
use Test::Smoke;
use Test::Smoke::Smoker;

use Getopt::Long;
my %opt = (
    ddir   => undef,
    v      => 2,

    config => undef,
    help   => 0,
    man    => 0,
);
my $defaults = Test::Smoke::Smoker->config( 'all_defaults' );

my $myusage = "Usage: $0 -d <destdir> file[ file ...]";
GetOptions( \%opt,
    'ddir|d=s', 'v|verbose=i',

    'help|h', 'man|m',

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
                $opt{type} ||= $conf->{sync_type};
            } elsif ( exists $conf->{ $option } ) {
                $opt{ $option } ||= $conf->{ $option }
            }
        }
    } else {
        warn "WARNING: Could not process '$opt{config}': " . 
             Test::Smoke->config_error . "\n";
    }
}

foreach ( keys %$defaults ) {
    next if defined $opt{ $_ };
    $opt{ $_ } = exists $conf->{ $_ } ? $conf->{ $_ } : $defaults->{ $_ };
}

my $dev_null = File::Spec->devnull;
local *NULL;
open NULL, "> $dev_null";

chdir $opt{ddir} or die "Cannot chdir($opt{ddir})\n";
my $smoker = Test::Smoke::Smoker->new( \*NULL, \%opt );
foreach my $test ( @ARGV ) {
    print "Extending with harness: '$test'\n";
    $smoker->extend_with_harness( $test );
}
