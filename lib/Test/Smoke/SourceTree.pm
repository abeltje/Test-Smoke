package Test::Smoke::SourceTree;
use strict;

# $Id$
use vars qw( $VERSION @EXPORT_OK %EXPORT_TAGS );
$VERSION = '0.005';

use File::Spec;
use File::Find;
use Carp;

use base 'Exporter';
%EXPORT_TAGS = (
    mani_const => [qw( &ST_MISSING &ST_UNDECLARED )],
    const      => [qw( &ST_MISSING &ST_UNDECLARED )],
);
@EXPORT_OK = @{ $EXPORT_TAGS{mani_const} };

=head1 NAME

Test::Smoke::SourceTree - Manipulate the perl source-tree

=head1 SYNOPSIS

    use Test::Smoke::SourceTree qw( :mani_const );

    my $tree = Test::Smoke::SourceTree->new( $tree_dir );

    my $mani_check = $tree->check_MANIFEST;
    foreach my $file ( sort keys %$mani_check ) {
        if ( $mani_check->{ $file } == ST_MISSING ) {
            print "MANIFEST declared '$file' but it is missing\n";
        } elsif ( $mani_check->{ $file } == ST_UNDECLARED ) {
            print "MANIFEST did not declare '$file'\n";
        }
    }

    $tree->clean_from_MANIFEST;

=head1 DESCRIPTION

=over 4

=cut

# Define some constants
sub ST_MISSING()    { return 1 }
sub ST_UNDECLARED() { return 0 }

=item Test::Smoke::SourceTree->new( $tree_dir )

C<new()> creates a new object, this is a simple scalar containing
C<< File::Spec->rel2abs( $tree_dir) >>.

=cut

sub new {
    my $proto = shift;
    my $class = ref $proto ? ref $proto : $proto;

    croak sprintf "Usage: my \$tree = %s->new( <directory> )", __PACKAGE__
        unless @_;
    my $self = File::Spec->rel2abs( shift );
    return bless \$self, $class;
}

=item $tree->canonpath( )

C<canonpath()> returns the canonical name for the path, 
see L<File::Spec>.

=cut

sub canonpath {
    my $self = shift;
    return File::Spec->canonpath( $$self );
}

=item $tree->rel2abs( [$base_dir] )

C<rel2abs()> returns the absolute path, see L<File::Spec>.

=cut

sub rel2abs {
    my $self = shift;
    return File::Spec->rel2abs( $$self, @_ );
}

=item $tree->abs2rel( [$base_dir] )

C<abs2rel()> returns  a relative path, 
see L<File::Spec>.

=cut

sub abs2rel {
    my $self = shift;
    return File::Spec->abs2rel( $$self, @_ );
}

=item $tree->mani2abs( $file[, $base_path] )

C<mani2abs()> returns the absolute filename of C<$file>, which should 
be in "MANIFEST" format (i.e. using '/' as directory separator).

=cut

sub mani2abs {
    my $self = shift;

    my @split_path = split m|/|, shift;
    my $base_path = File::Spec->rel2abs( $$self, @_ );
    return File::Spec->catfile( $base_path, @split_path );
}

=item $tree->abs2mani( $file )

C<abs2mani()> returns the MANIFEST style filename.

=cut

sub abs2mani {
    my $self = shift;
    my $relfile = File::Spec->abs2rel( File::Spec->canonpath( shift ),
                                       $$self );
    my( undef, $directories, $file ) = File::Spec->splitpath( $relfile );
    my @dirs = grep $_ && length $_ => File::Spec->splitdir( $directories );
    push @dirs, $file;
    return join '/', @dirs;
}

=item $tree->check_MANIFEST( @ignore )

C<check_MANIFEST()> reads the B<MANIFEST> file from C<< $$self >> and
compares it with the actual contents of C<< $$self >>.

Returns a hashref with suspicious entries (if any) as keys that have a 
value of either B<ST_MISSING> (not in directory) or B<ST_UNDECLARED>
(not in MANIFEST).

=cut

sub check_MANIFEST {
    my $self = shift;

    my %manifest = %{ $self->_read_mani_file( 'MANIFEST' ) };

    my %ignore = map { 
        $_ => undef 
    } ( ".patch", "MANIFEST.SKIP", @_ ), 
      keys %{ $self->_read_mani_file( 'MANIFEST.SKIP', 1 ) };

    # Walk the tree, remove all found files from %manifest
    # and add other files to %manifest 
    # unless they are in the ignore list
    require File::Find;
    File::Find::find( sub {
        -f or return;
        my $mani_name = $self->abs2mani( $File::Find::name );
        if ( exists $manifest{ $mani_name } ) {
            delete $manifest{ $mani_name };
        } else {
            $manifest{ $mani_name } = ST_UNDECLARED
                unless exists $ignore{ $mani_name };
        }
    }, $$self );

    return \%manifest;
} 

=item $self->_read_mani_file( $path[, $no_croak] )

C<_read_mani_file()> reads the contents of C<$path> like it is a
MANIFEST typeof file and returns a ref to hash with all values set
C<ST_MISSING>.

=cut

sub _read_mani_file {
    my $self = shift;
    my( $path, $no_croak ) = @_;

    my $manifile = $self->mani2abs( $path );
    local *MANIFEST;
    open MANIFEST, "< $manifile" or do {
        $no_croak and return { };
        croak( "Can't open '$manifile': $!" );
    };

    my %manifest = map { 
        m|(\S+)|;
        ( $1 => ST_MISSING );
    } <MANIFEST>;
    close MANIFEST;

    return \%manifest;
}

=item $tree->clean_from_MANIFEST( )

C<clean_from_MANIFEST()> removes all files from the source-tree that are
not declared in the B<MANIFEST> file.

=cut

sub clean_from_MANIFEST {
    my $self = shift;

    my $mani_check = $self->check_MANIFEST( @_ );
    my @to_remove = grep {
        $mani_check->{ $_ } == ST_UNDECLARED 
    } keys %$mani_check;

    foreach my $entry ( @to_remove ) {
        my $file = $self->mani2abs( $entry );
        1 while unlink $file;
    }
}

=item copy_from_MANIFEST( $dest_dir[, $verbose] )

C<_copy_from_MANIFEST()> uses the B<MANIFEST> file from C<$$self>
to copy a source-tree to C<< $dest_dir >>.

=cut

sub copy_from_MANIFEST {
    my( $self, $dest_dir, $verbose ) = @_;

    my $manifest = $self->mani2abs( 'MANIFEST' );

    local *MANIFEST;
    open MANIFEST, "< $manifest" or do {
        carp "Can't open '$manifest': $!\n";
        return undef;
    };

    $verbose and print "Reading from '$manifest'";
    my @manifest_files = map {
        /^([^\s]+)/ ? $1 : $_
    } <MANIFEST>;
    close MANIFEST;
    my $dot_patch = $self->mani2abs( '.patch' );
    -f $dot_patch and push @manifest_files, '.patch';

    $verbose and printf " %d items OK\n", scalar @manifest_files;

    my $dest = $self->new( $dest_dir );
    File::Path::mkpath( $$dest, $verbose ) unless -d $$dest;

    require File::Basename;
    require File::Copy;
    foreach my $file ( @manifest_files ) {
        $file or next;

        my $dest_name = $dest->mani2abs( $file );
        my $dest_path = File::Basename::dirname( $dest_name );

        File::Path::mkpath( $dest_path, $verbose ) unless -d $dest_path;

        $verbose > 1 and print "$file -> $dest_name ";
        my $mode = ( stat $self->mani2abs( $file ) )[2] & 07777;
        -f $dest_name and unlink $dest_name;
        my $ok = File::Copy::syscopy( $self->mani2abs( $file ), $dest_name );
        $ok and $ok &&= chmod $mode, $dest_name;
        $ok or carp "copy '$file' ($dest_path): $!\n";
        $ok && $verbose > 1 and print "OK\n";
    }
}

1;

=back

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
