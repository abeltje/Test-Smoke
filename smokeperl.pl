#! /usr/bin/perl -w
use strict;
$|=1;

use Cwd;
use File::Spec;
use FindBin;
use lib File::Spec->catdir( $FindBin::Bin, 'lib' );

use Getopt::Long;
my %options = ( config => 'smokecurrent_config', run => 1,
                fetch => 1, patch => 1, mail => 1, 
                is56x => undef, smartsmoke => undef );
GetOptions( \%options, 
    'config|c=s', 
    'fetch!', 
    'patch!', 
    'mail!',
    'run!',
    'is56x',
    'smartsmoke!',
);

use vars qw( $conf $VERSION );
$VERSION = '1.16_22';

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

  --is56x                  This is a perl-5.6.x smoke
  --[no]smartsmoke         Don't smoke unless patchlevel changed

=cut

# Try cwd() first, then $FindBin::Bin
my $config_file = File::Spec->catfile( cwd(), $options{config} );
-e $config_file and eval { require $config_file; };
if ( $@ ) {
    $config_file = File::Spec->catfile( $FindBin::Bin, $options{config} );
    eval { require $config_file; };
}
$@ and die "!!!Please run 'configsmoke.pl'!!!\nCannot find configuration: $!";

$conf->{is56x} = $options{is56x} if defined $options{is56x};
$conf->{smartsmoke} = $options{smartsmoke} if defined $options{smartsmoke};

use Test::Smoke::Syncer;
use Test::Smoke::Patcher;
use Test::Smoke::Mailer;
use Test::Smoke::Util qw( get_patch );
use Cwd;

my $was_patchlevel = get_patch( $conf->{ddir} ) || -1;
FETCHTREE: {
    unless ( $options{fetch} && $options{run} ) {
        $conf->{v} and print "Skipping synctree\n";
        last FETCHTREE;
    }
    my $syncer = Test::Smoke::Syncer->new( $conf->{sync_type}, $conf );
    $syncer->sync;
}
my $now_patchlevel = get_patch( $conf->{ddir} );

if ( $conf->{smartsmoke} && ($was_patchlevel eq $now_patchlevel) ) {
    $conf->{v} and print "Skipping this smoke, patchlevel ($was_patchlevel)" .
                         " did not change.\n";
    exit(0);
}

PATCHAPERL: {
    unless ( $options{patch} && $options{run} ) {
        $conf->{v} && exists $conf->{patch_type} &&
        $conf->{patch_type} eq 'multi' and
            print "Skipping patching ($conf->{pfile})\n";
        last PATCHAPERL;
    }
    last PATCHAPERL unless exists $conf->{patch_type} && 
                           $conf->{patch_type} eq 'multi' && $conf->{pfile};
    if ( $^O eq 'MSWin32' ) {
        Test::Smoke::Patcher->config( flags => TRY_REGEN_HEADERS );
    }
    my $patcher = Test::Smoke::Patcher->new( $conf->{patch_type}, $conf );
    eval { $patcher->patch };
}

my $cwd = cwd();
chdir $conf->{ddir} or die "Cannot chdir($conf->{ddir}): $!";
MKTEST: {
    local @ARGV = ( $conf->{cfg} );
    push  @ARGV, ( "--locale", $conf->{locale} ) if $conf->{locale};
    push  @ARGV, "--forest",  $conf->{fdir}
       if $conf->{sync_type} eq 'forest' && $conf->{fdir};
    push  @ARGV, "-v", $conf->{v} if $conf->{v};
    push  @ARGV, "--norun" unless $options{run};
    push  @ARGV, "--is56x" if $conf->{is56x};
    push  @ARGV, "--force-c-locale" if $conf->{force_c_locale};
    push  @ARGV, @{ $conf->{w32args} } if exists $conf->{w32args};
    my $mktest = File::Spec->catfile( $FindBin::Bin, 'mktest.pl' );
    $conf->{v} > 1 and print "$mktest @ARGV\n";
    local $0 = $mktest;
    do $mktest or die "Error 'mktest': $@";
}

MKOVZ: {
    last MKOVZ unless $options{run};
    local @ARGV = ( 'nomail', $conf->{ddir} );
    push  @ARGV, $conf->{locale} if $conf->{locale};
    my $mkovz = File::Spec->catfile( $FindBin::Bin, 'mkovz.pl' );
    local $0 = $mkovz;
    do $mkovz or die "Error in mkovz.pl: $@";
}

MAILRPT: {
    unless ( $options{mail} && $options{run} ) {
        $conf->{v} and print "Skipping mailrpt\n";
        last MAILRPT;
    }
    my $mailer = Test::Smoke::Mailer->new( $conf->{mail_type}, $conf );
    $mailer->mail;
}
chdir $cwd;

=head1 SEE ALSO

L<configsmoke.pl>, L<mktest.pl>, L<mkovz.pl>

=head1 COPYRIGHT

(c) 2002-2003, All rights reserved.

  * Abe Timmerman <abeltje@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See:

=over 4

=item * http://www.perl.com/perl/misc/Artistic.html

=item * http://www.gnu.org/copyleft/gpl.html

=back

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
