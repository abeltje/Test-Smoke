#! /usr/bin/perl -w
use strict;

use Getopt::Long;
use File::Spec;
use Cwd;
use FindBin;
use lib File::Spec->catdir( $FindBin::Bin, 'lib' );
use Test::Smoke::Patcher;

use vars qw( $VERSION $conf );
$VERSION = '0.001';

my %opt = (
    type    => 'multi',
    ddir    => '',
    pfile   => '',
    v       => 0,

    config  => '',
    help    => 0,
    man     => 0,
);

my $defaults = Test::Smoke::Patcher->config( 'all_defaults' );

my %valid_type = map { $_ => 1 } qw( single multi );

=head1 NAME

patchtree.pl - Patch the sourcetree

=head1 SYNOPSIS

    $ ./patchtree.pl -f patchfile -d ../perl-current [--help | more options]

or

    $ ./mailrpt.pl -c smokeperl_config

=head1 OPTIONS

=over 4

=item * B<Configuration file>

    -c | --config <configfile> Use the settings from the configfile

F<patchtree.pl> can use the configuration file created by F<configsmoke.pl>.
Other options can override the settings from the configuration file.

=item * B<General options>

    -d | --ddir <directory>  Set the directory for the source-tree (cwd)
    -f | --pfile <patchfile> Set the resource containg patch info
    -v | --verbose           Be verbose

=back

=cut

GetOptions( \%opt,
    'pfile|f=s', 'ddir|d=s', 'v|verbose+',

    'popts=s',

    'help|h', 'man|m',

    'config|c=s',
) or do_pod2usage( verbose => 1 );

$opt{man}  and do_pod2usage( verbose => 2, exitval => 0 );
$opt{help} and do_pod2usage( verbose => 1, exitval => 0 );

if ( $opt{config} && -f $opt{config} ) {
    require $opt{config};

    foreach my $option ( keys %opt ) {
        if ( $option eq 'type' ) {
            $opt{type} ||= $conf->{patch_type};
        } elsif ( exists $conf->{ $option } ) {
            $opt{ $option } ||= $conf->{ $option }
        }
    }
}

$opt{ $_ } ||= $defaults->{ $_ } foreach keys %$defaults;

exists $valid_type{ $opt{type} } or do_pod2usage( verbose => 0 );

$opt{ddir} && -d $opt{ddir} or do_pod2usage( verbose => 0 );
$opt{pfile} && -f $opt{pfile} or do_pod2usage( verbose => 0 );

if ( $^O eq 'MSWin32' ) {
    Test::Smoke::Patcher->config( flags => TRY_REGEN_HEADERS );
}
my $patcher = Test::Smoke::Patcher->new( $opt{type} => \%opt );
eval{ $patcher->patch };

sub do_pod2usage {
    eval { require Pod::Usage };
    if ( $@ ) {
        print <<EO_MSG;
Usage: $0 -t <type> -d <directory> [options]

Use 'perldoc $0' for the documentation.
Please install 'Pod::Usage' for easy access to the docs.

EO_MSG
        my %p2u_opt = @_;
        exit( exists $p2u_opt{exitval} ? $p2u_opt{exitval} : 1 );
    } else {
        Pod::Usage::pod2usage( @_ );
    }
}

=head1 SEE ALSO

L<Test::Smoke::Patcher>

=head1 COPYRIGHT

(c) 2002-2003, All rights reserved.

  * Abe Timmerman <abeltje@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See:

=over 4

item * http://www.perl.com/perl/misc/Artistic.html

item * http://www.gnu.org/copyleft/gpl.html

=back

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
