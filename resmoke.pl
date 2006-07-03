#! /usr/bin/perl -w
use strict;

# $Id$
use vars qw( $VERSION );
$VERSION = '0.001';

use File::Spec::Functions;
use Cwd;
use FindBin;
use lib File::Spec->catdir( $FindBin::Bin, 'lib' );
use lib $FindBin::Bin;
use Test::Smoke;
use Test::Smoke::Smoker;
use Test::Smoke::BuildCFG;
use Test::Smoke::Reporter;
use Test::Smoke::Util qw( skip_config );

use Getopt::Long;
my %opt = (
    ddir   => undef,
    v      => 2,

    status => 'c',
    n      => 1,

    config => undef,
    help   => 0,
    man    => 0,
);
my $defaults = Test::Smoke::Smoker->config( 'all_defaults' );

my $myusage = "Usage: $0 -d <destdir> file[ file ...]";
GetOptions( \%opt,
    'ddir|d=s', 'v|verbose=i',

    'status|s=s', 'n=i',

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

# Find the config to resmoke
my $rscfg = find_config( $opt{status}, $opt{n} );
defined $rscfg or
    die "Cannot find a matching build configuration ($opt{status})!\n";

my $cwd = cwd();
{
    my $BuildCFG = Test::Smoke::BuildCFG->new( \$rscfg, v => 0 );
    chdir $opt{ddir} or die "Cannot chdir($opt{ddir}): $!";

    print "resmoke '$rscfg'\n";
    my $logfile = catfile $opt{ddir}, 'resmoke.out';
    local *LOG;
    open LOG, "> $logfile" or die "Cannot create($logfile): $!";
    my $Policy   = Test::Smoke::Policy->new( updir(), 0,
                                             $BuildCFG->policy_targets );

    $conf->{v} = 2;
    my $smoker   = Test::Smoke::Smoker->new( \*LOG, $conf );

    for my $bcfg ( $BuildCFG->configurations ) {
        $smoker->ttylog( join "\n", 
                              "", "Configuration: $bcfg", "-" x 78, "" );
        $smoker->smoke( $bcfg, $Policy );
    }

}
chdir $cwd;

sub find_config {
    my( $state, $cnt ) = @_;
    $state ||= 'c';
    $cnt ||= 1;

    for my $bstat ( _get_config_states() ) {
        my $states = join "", values %{ $bstat->{stat} };
        $states =~ /$state/ or next;
        --$cnt == 0 and
            return $bstat->{cfg};
    }
    return;
}

sub _get_config_states {
    my $report = Test::Smoke::Reporter->new( ddir => $opt{ddir}, v => 0 );
    my $bcfgs  = Test::Smoke::BuildCFG->new( $conf->{cfg}, { v => 0 } );

    my @buildstat;
    for my $bcfg ( $bcfgs->configurations ) {
        skip_config( $bcfg ) and next;

        $bcfg->rm_arg( '-Dusedevel' );
        my $chkcfg = Test::Smoke::BuildCFG::new_configuration( "$bcfg" );
        my $stat;
        if ( $chkcfg->has_arg( '-DDEBUGGING' ) ) {
            $chkcfg->rm_arg( '-DDEBUGGING' );
            $stat = $report->{_rpt}{ "$chkcfg" }{D};
        } else {
            $stat = $report->{_rpt}{ "$chkcfg" }{N};
        }
        push @buildstat, { cfg => "$bcfg", stat => $stat };
    }
    return wantarray ? @buildstat : \@buildstat;
}
