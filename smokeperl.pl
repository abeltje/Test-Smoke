#! /usr/bin/perl -w
use strict;
$|=1;

# $Id$
use vars qw( $VERSION );
$VERSION = Test::Smoke->VERSION;

use Cwd;
use File::Spec;
use File::Path;
use File::Copy;
use FindBin;
use lib File::Spec->catdir( $FindBin::Bin, 'lib' );
use lib $FindBin::Bin;
use Config;
use Test::Smoke::Syncer;
use Test::Smoke::Patcher;
use Test::Smoke;
use Test::Smoke::Reporter;
use Test::Smoke::Mailer;
use Test::Smoke::Util qw( get_patch calc_timeout do_pod2usage );

use Getopt::Long;
Getopt::Long::Configure( 'pass_through' );
my %options = ( config => 'smokecurrent_config', run => 1,
                fetch => 1, patch => 1, mail => undef, archive => undef,
                continue => 0, ccp5p_onfail => undef,
                is56x => undef, defaultenv => undef, smartsmoke => undef );

my $myusage = "Usage: $0 [-c configname]";
GetOptions( \%options, 
    'config|c=s', 
    'fetch!', 
    'patch!',
    'ccp5p_onfail!',
    'mail!',
    'run!',
    'archive!',
    'is56x',
    'defaultenv!',
    'continue',
    'smartsmoke!',
    'snapshot|s=i',

    'help|h', 'man',
) or do_pod2usage(  verbose => 1, myusage => $myusage );

$options{ man} 
    and do_pod2usage( verbose => 2, exitval => 0, myusage => $myusage );
$options{help} 
    and do_pod2usage( verbose => 1, exitval => 0, myusage => $myusage );

=head1 NAME

smokeperl.pl - The perl Test::Smoke suite

=head1 SYNOPSIS

    $ ./smokeperl.pl [-c configname]

or

    C:\smoke>perl smokeperl.pl [-c configname]

=head1 OPTIONS

It can take these options

  --config|-c <configname> See configsmoke.pl (smokecurrent_config)
  --nofetch                Skip the synctree step
  --nopatch                Skip the patch step
  --nomail                 Skip the mail step
  --noarchive              Skip the archive step (if applicable)
  --[no]ccp5p_onfail       Do (not) send failure reports to perl5-porters

  --continue               Try to continue an interrupted smoke
  --is56x                  This is a perl-5.6.x smoke
  --defaultenv             Run a smoke in the default environment
  --[no]smartsmoke         Don't smoke unless patchlevel changed
  --snapshot <patchlevel>  Set a new patchlevel for snapshot smokes

All other arguments are passed to F<Configure>!

=head1 DESCRIPTION

F<smokeperl.pl> is the main program in this suite. It combines all the
front-ends internally and does some sanity checking.

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
    for qw( run fetch patch mail archive );
# Make command-line options override configfile
defined $options{ $_ } and $conf->{ $_ } = $options{ $_ }
    for qw( is56x defaultenv continue
            smartsmoke run fetch patch mail ccp5p_onfail archive );

if ( $options{continue} ) {
    $options{v} and print "Will try to continue current smoke\n";
} else {
    synctree();
    patchtree();
}

my $cwd = cwd();
chdir $conf->{ddir} or die "Cannot chdir($conf->{ddir}): $!";
call_mktest();
genrpt();
mailrpt();
chdir $cwd;
archiverpt();

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
        exit(42);
    };
    $Config{d_alarm} and alarm $timeout;

    run_smoke( $conf->{continue}, @ARGV );
}

sub genrpt {
    return unless $options{run};
    my $reporter = Test::Smoke::Reporter->new( $conf );
    $reporter->write_to_file;
}

sub mailrpt {
    unless ( $conf->{mail} && $options{run} ) {
        $conf->{v} and print "Skipping mailrpt\n";
        return;
    }
    my $mailer = Test::Smoke::Mailer->new( $conf->{mail_type}, $conf );
    $mailer->mail or warn "[$conf->{mail_type}] " . $mailer->error;
}

sub archiverpt {
    return unless $conf->{archive};
    return unless exists $conf->{adir};
    return if $conf->{adir} eq "";
    -d $conf->{adir} or do {
        mkpath( $conf->{adir}, 0, 0775 ) or 
            die "Cannot create '$conf->{adir}': $!";
    };

    my $patch_level = get_patch( $conf->{ddir} );
    $patch_level =~ tr/ //sd;

    my $archived_rpt = "rpt${patch_level}.rpt";

    # Do not archive if it is already done
    return if -f File::Spec->catfile( $conf->{adir}, $archived_rpt );

    copy( File::Spec->catfile( $conf->{ddir}, 'mktest.rpt' ),
          File::Spec->catfile( $conf->{adir}, $archived_rpt ) ) or
        die "Cannot copy to '$archived_rpt': $!";

    SKIP_LOG: {
        my $archived_log = "log${patch_level}.log";
        last SKIP_LOG unless defined $conf->{lfile};
        last SKIP_LOG 
            unless -f File::Spec->catfile( $FindBin::Bin, $conf->{lfile} );
        copy( File::Spec->catfile( $FindBin::Bin, $conf->{lfile} ),
              File::Spec->catfile( $conf->{adir}, $archived_log ) ) or
            die "Cannot copy to '$archived_log': $!";
    }
}

sub snapshot_name {
    my( $plevel ) = $options{snapshot} =~ /(\d+)/;
    my $sfile = $conf->{sfile};
    if ( $sfile ) {
        $sfile =~ s/([-@])\d+\./$1$plevel./;
    } else {
        my $sep = $conf->{is56x} ? '562-' : '@';
        my $ext = $conf->{snapext} || 'tar.gz';
        $sfile = "perl${sep}${plevel}.$ext";
    }
    return $sfile;
}

=head1 SEE ALSO

L<README>, L<FAQ>, L<configsmoke.pl>, L<mktest.pl>, L<mkovz.pl>

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
