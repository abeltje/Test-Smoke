package Test::Smoke;
use strict;

# $Id$
use vars qw( $VERSION $conf @EXPORT );
$VERSION = '1.17_65';

use base 'Exporter';
@EXPORT  = qw( $conf &read_config &run_smoke );

my $ConfigError;

use Test::Smoke::Policy;
use Test::Smoke::BuildCFG;
use Test::Smoke::Smoker;
use Test::Smoke::SourceTree qw( :mani_const );
use Test::Smoke::Util qw( get_patch );
use Config;

=head1 NAME

Test::Smoke - The Perl core test smoke suite

=head1 SYNOPSIS

    use Test::Smoke;

    use vars qw( $VERSION );
    $VERSION = Test::Smoke->VERSION;

    read_config( $config_name ) or warn Test::Smoke->config_error; 
    

=head1 DESCRIPTION

C<Test::Smoke> exports C<$conf> and C<read_config()> by default.

=over 4

=item Test::Smoke::read_config( $config_name )

=cut

sub read_config {
    my( $config_name ) = @_;

    $config_name = 'smokecurrent_config' 
        unless defined $config_name && length $config_name;
    $config_name .= '_config' 
        unless $config_name =~ /_config$/ || -f $config_name;

    # Enable reloading by hackery
    delete $INC{ $config_name } if exists $INC{ $config_name };
    eval { require $config_name };
    $ConfigError = $@ ? $@ : undef;

    return defined $ConfigError ? undef : 1;
}

=item Test::Smoke->config_error()

Return the value of C<$ConfigError>

=cut

sub config_error {
    return $ConfigError;
}

=item is_win32( )

C<is_win32()> returns true if  C<< $^O eq "MSWin32" >>.

=cut

sub is_win32() { $^O eq "MSWin32" }

=item do_manifest_check( $ddir, $smoker )

C<do_manifest_check()> uses B<Test::Smoke::SourceTree> to do the 
MANIFEST check.

=cut

sub do_manifest_check {
    my( $ddir, $smoker ) = @_;

    my $tree = Test::Smoke::SourceTree->new( $ddir );
    my $mani_check = $tree->check_MANIFEST( 'mktest.out' );
    foreach my $file ( sort keys %$mani_check ) {
        if ( $mani_check->{ $file } == ST_MISSING ) {
            $smoker->log( "MANIFEST declared '$file' but it is missing\n" );
        } elsif ( $mani_check->{ $file } == ST_UNDECLARED ) {
            $smoker->log( "MANIFEST did not declare '$file'\n" );
        }
    }
}

=item run_smoke( $continue, $patch )

C<run_smoke()> sets up de build environment and gets the private Policy
file and build configurations and then runs the smoke stuff for all 
configurations.

=cut

sub run_smoke {
    my $continue = shift;
    my $patch = shift || Test::Smoke::Util::get_patch( $conf->{ddir} );

    local *LOG;
    my $mode = $continue ? ">>" : ">";
    open LOG, "$mode " . File::Spec->catfile( $conf->{ddir}, 'mktest.out' )  or
        die "Cannot create 'mktest.out': $!";

    my $Policy   = Test::Smoke::Policy->new( File::Spec->updir, $conf->{v} );
    my $BuildCFG = Test::Smoke::BuildCFG->new( $conf->{cfg}, v => $conf->{v} );

    my $smoker   = Test::Smoke::Smoker->new( \*LOG, $conf );
    $smoker->mark_in;

    $conf->{v} && $conf->{defaultenv} and
        $smoker->tty( "Running smoke tests without \$ENV{PERLIO}\n" );

    unless ( $continue ) {
        $smoker->ttylog( "Smoking patch $patch\n" ); 
        do_manifest_check( $conf->{ddir}, $smoker );
    }

    chdir $conf->{ddir} or die "Cannot chdir($conf->{ddir}): $!";
    foreach my $this_cfg ( $BuildCFG->configurations ) {
        $smoker->mark_out; $smoker->mark_in;
        if ( skip_config( $this_cfg ) ) {
            $smoker->ttylog( "Skipping: '$this_cfg'\n" );
            next;
        }

        $smoker->ttylog( join "\n", 
                              "", "Configuration: $this_cfg", "-" x 78, "" );
        $smoker->smoke( $this_cfg, $Policy );
    }

    $smoker->ttylog( "Finished smoking $patch\n" );
    $smoker->mark_out;

    close LOG or do {
        require Carp;
        Carp::carp "Error on closing logfile: $!";
   };
}

=item skip_config( $config ) 

Returns true if this config should be skipped.

=cut

sub skip_config {
    my( $config ) = @_;

    my $skip = $config->has_arg(qw( -Uuseperlio -Dusethreads )) ||
               $config->has_arg(qw( -Uuseperlio -Duseithreads ));
    return $skip;
}

1;

=back

=head1 REVISION

$Id$

=head1 COPYRIGHT

(c) 2003, All rights reserved.

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
