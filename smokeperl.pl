#! /usr/bin/perl -w
use strict;
$|=1;

use Cwd;
use File::Spec;
use FindBin;
use lib File::Spec->catdir( $FindBin::Bin, 'lib' );

use Getopt::Long;
my %options = ( config => 'smokecurrent_config', run => 1,
                fetch => 1, patch => 1, mail => undef, 
                continue => 0,
                is56x => undef, smartsmoke => undef );
GetOptions( \%options, 
    'config|c=s', 
    'continue',
    'fetch!', 
    'patch!', 
    'mail!',
    'run!',
    'is56x',
    'smartsmoke!',
    'snapshot|s=i',
);

use Config;
use Test::Smoke;
use vars qw( $VERSION );
$VERSION = Test::Smoke->VERSION;
# $Id$

=head1 NAME

smokeperl.pl - The perl Test::Smoke suite

=head1 SYNOPSIS

    $ ./smokeperl.pl [-c configname]

or

    C:\smoke\Test-Smoke-1.17>perl smokeperl.pl [-c configname]

=head1 OPTIONS

It can take these options

  --config|-c <configname> See configsmoke.pl (smokecurrent_config)
  --nofetch                Skip the synctree step
  --nopatch                Skip the patch step
  --nomail                 Skip the mail step

  --continue               Try to continue an interrupted smoke
  --is56x                  This is a perl-5.6.x smoke
  --[no]smartsmoke         Don't smoke unless patchlevel changed

=cut

# Try cwd() first, then $FindBin::Bin
my $config_file = File::Spec->catfile( cwd(), $options{config} );
unless ( read_config( $config_file ) ) {
    $config_file = File::Spec->catfile( $FindBin::Bin, $options{config} );
    read_config( $config_file );
}
defined Test::Smoke->config_error and 
    die "!!!Please run 'configsmoke.pl'!!!\nCannot find configuration: $!";

# Correction for backward compatability
!defined $options{ $_ } && !exists $conf->{ $_ } and $options{ $_ } = 1
    for qw( run fetch patch mail );
# Make command-line options override configfile
defined $options{ $_ } and $conf->{ $_ } = $options{ $_ }
    for qw( is56x smartsmoke run fetch patch mail );

use Test::Smoke::Syncer;
use Test::Smoke::Patcher;
use Test::Smoke::Mailer;
use Test::Smoke::Util qw( get_patch );
use Cwd;

if ( $options{continue} ) {
    $options{v} and print "Will try to continue current smoke\n";
    my $cfg = Test::Smoke::BuildCFG->new( $conf->{cfg}, v => $conf->{v} );
    my @found = configs_from_log( $conf->{ddir} );
    my %found = map { ( $_ => 1 ) } @found;
    my @pass;
    foreach my $config ( $cfg->configurations ) {
        push @pass, $config unless exists $found{ "$config" } ||
                                   Test::Smoke::skip_config( $config );
    }
    $conf->{cfg} = { _list => \@pass };
} else {
    synctree();
    patchtree();
}

my $cwd = cwd();
chdir $conf->{ddir} or die "Cannot chdir($conf->{ddir}): $!";
call_mktest();
call_mkovz();
mailrpt();
chdir $cwd;

sub synctree {
    my $was_patchlevel = get_patch( $conf->{ddir} ) || -1;
    my $now_patchlevel = $was_patchlevel;
    FETCHTREE: {
        unless ( $options{fetch} && $options{run} ) {
            $conf->{v} and print "Skipping synctree\n";
            last FETCHTREE;
        }
        if ( $options{snapshot} ) {
            if ( $conf->{sync_type} eq 'snapshot' ||
               ( $conf->{sync_type} eq 'forest'   && 
                 $conf->{fsync} eq 'snapshot' ) ) {

                $conf->{sfile} = snapshot_name();
            } else {
                die "<--snapshot> is not valid now, please reconfigure!";
            }
            $conf->{sfile} = snapshot_name();
        }
        my $syncer = Test::Smoke::Syncer->new( $conf->{sync_type}, $conf );
        $now_patchlevel = $syncer->sync;
        $conf->{v} and 
            print "$conf->{ddir} now up to patchlevel $now_patchlevel\n";
    }

    if ( $conf->{smartsmoke} && ($was_patchlevel eq $now_patchlevel) ) {
        $conf->{v} and 
            print "Skipping this smoke, patchlevel ($was_patchlevel)" .
                  " did not change.\n";
        exit(0);
    }
}

sub patchtree {
    PATCHAPERL: {
        unless ( $options{patch} && $options{run} ) {
            $conf->{v} && exists $conf->{patch_type} &&
            $conf->{patch_type} eq 'multi' and
                print "Skipping patching ($conf->{pfile})\n";
            last PATCHAPERL;
        }
        last PATCHAPERL unless exists $conf->{patch_type} && 
                               $conf->{patch_type} eq 'multi' && 
                               $conf->{pfile};
        if ( $^O eq 'MSWin32' ) {
            Test::Smoke::Patcher->config( flags => TRY_REGEN_HEADERS );
        }
        my $patcher = Test::Smoke::Patcher->new( $conf->{patch_type}, $conf );
        eval { $patcher->patch };
    }
}

sub call_mktest {
    my $timeout = 0;
    if ( $Config{d_alarm} && $conf->{killtime} ) {
        $timeout = calc_timeout( $conf->{killtime} );
        $conf->{v} and printf "Setup alarm: %s\n",
                              scalar localtime( time() + $timeout );
    }
    $timeout and local $SIG{ALRM} = sub {
        warn "This smoke is aborted ($conf->{killtime})\n";
        call_mkovz();
        mailrpt();
        exit;
    };
    $Config{d_alarm} and alarm $timeout;

    run_smoke();
}

sub call_mkovz {
    return unless $options{run};
    local @ARGV = ( 'nomail', $conf->{ddir} );
    push  @ARGV, $conf->{locale} if $conf->{locale};
    my $mkovz = File::Spec->catfile( $FindBin::Bin, 'mkovz.pl' );
    local $0 = $mkovz;
    do $mkovz or die "Error in mkovz.pl: $@";
}

sub mailrpt {
    unless ( $conf->{mail} && $options{run} ) {
        $conf->{v} and print "Skipping mailrpt\n";
        return;
    }
    my $mailer = Test::Smoke::Mailer->new( $conf->{mail_type}, $conf );
    $mailer->mail;
}

sub calc_timeout {
    my( $killtime ) = @_;
    my $timeout = 0;
    if ( $killtime =~ /^\+(\d+):([0-5]?[0-9])$/ ) {
        $timeout = 60 * (60 * $1 + $2 );
    } elsif ( $killtime =~ /^((?:[0-1]?[0-9])|(?:2[0-3])):([0-5]?[0-9])$/ ) {
        my $time_min = 60 * $1 + $2;
        my( $now_m, $now_h ) = (localtime)[1, 2];
        my $now_min = 60 * $now_h + $now_m;
        my $kill_min = $time_min - $now_min;
        $kill_min += 60 * 24 if $kill_min < 0;
        $timeout = 60 * $kill_min;
    }
    return $timeout;
}

sub configs_from_log {
    my( $dir ) = @_;

    my $log_name = File::Spec->catfile( $dir, "mktest.out" );
    my @configs;
    local *LOG;
    open LOG, "< $log_name" or die "Cannot continue: $!";
    my( $smoke, $finish ) = ( 0, undef );
    while ( <LOG> ) {
        /^Smoking patch (\d+)/ and $smoke = $1;
        /^Finished smoking patch $smoke/ and $finish = 1;
        /^Configuration:\s+(.*)/ or next;
        push @configs, $1;
    }
    close LOG;
    pop @configs unless $finish;
    return @configs;
}

sub snapshot_name {
    my( $plevel ) = $options{snapshot} =~ /(\d+)/;
    my $sfile = $conf->{sfile};
    if ( $sfile ) {
        $sfile =~ s/\d+/$plevel/;
    } else {
        $sfile = "perl\@$plevel.$conf->{snapext}";
    }
    return $sfile;
}

=head1 SEE ALSO

L<configsmoke.pl>, L<mktest.pl>, L<mkovz.pl>

=head1 REVISION

$Id$

=head1 COPYRIGHT

(c) 2002-2003, All rights reserved.

  * Abe Timmerman <abeltje@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See:

=over 4

=item * L<http://www.perl.com/perl/misc/Artistic.html>

=item * L<http://www.gnu.org/copyleft/gpl.html>

=back

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
