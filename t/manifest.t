#! perl -w
use strict;

# $Id$

use FindBin;
use lib $FindBin::Bin;
use TestLib;

use File::Find;
use File::Spec;
use Data::Dumper;

use Test::More tests => 14;
BEGIN { use_ok( 'Test::Smoke::Util' ); }

chdir 't' or die "chdir: $!" if -d 't';

SKIP: {
    my @MANIFEST = ( 'MANIFEST', get_dir( './' ) );
    local *MANIFEST;
    open MANIFEST, "> MANIFEST" or skip "Can't create MANIFEST: $!", 4;
    print MANIFEST "$_\n" for @MANIFEST;
    close MANIFEST or skip "Can't close MANIFEST: $!", 4;

    my $MANIFEST = check_MANIFEST( './' );
    isa_ok( $MANIFEST, 'HASH' , "check_MANIFEST() returns: " );

    # '.patch' should be missing here (added by check_MANIFEST())
    is( keys %$MANIFEST, 1, "All expected files are there" ) or
        diag( Dumper $MANIFEST );

    my $missing = (keys %$MANIFEST)[0];
    is( $missing, '.patch', "Yup, .patch is suspicious" );
    is( $MANIFEST->{ $missing }, 1, "and missing from the directory" );
    1 while unlink 'MANIFEST';
}

# Put more files in MANIFEST than present
SKIP: {
    my @extra_names = qw( Iamnotthere t/Iamnotthere );
    my @MANIFEST = ( 'MANIFEST', get_dir( './' ) );
    push @MANIFEST, @extra_names;

    local *MANIFEST;
    open MANIFEST, "> MANIFEST" or skip "Can't create MANIFEST: $!", 4;
    print MANIFEST "$_\n" for @MANIFEST;
    close MANIFEST or skip "Can't close MANIFEST: $!", 4;

    my $MANIFEST = check_MANIFEST( './' );
    # No need to bother with .patch anymore
    exists $MANIFEST->{ '.patch' } and delete $MANIFEST->{ '.patch' };

    is( keys %$MANIFEST, scalar @extra_names, "Some files suspicious" );

    my @extras = grep $MANIFEST->{ $_} => sort keys %$MANIFEST;
    is_deeply( \@extra_names, \@extras, "Same files we put in" );

    my $regex = join '|', map "\Q$_\E" => 
        sort { length( $b ) <=> length( $a ) } @extra_names;

    for my $file ( @extras ) {
        like( $file, "/^$regex\$/", "MANIFEST still has: $file" );
    }

    1 while unlink 'MANIFEST';
}

# Put less files in MANIFEST than present
SKIP: {
    my @MANIFEST = ( 'MANIFEST', get_dir( './' ) );
    my( $missing ) = splice @MANIFEST, -1, 1;

    local *MANIFEST;
    open MANIFEST, "> MANIFEST" or skip "Can't create MANIFEST: $!", 3;
    print MANIFEST "$_\n" for @MANIFEST;
    close MANIFEST or skip "Can't close MANIFEST: $!", 3;

    my $MANIFEST = check_MANIFEST( './' );
    # No need to bother with .patch anymore
    exists $MANIFEST->{ '.patch' } and delete $MANIFEST->{ '.patch' };

    is( keys %$MANIFEST, 1, "Found one suspicious file" );

    ok( exists $MANIFEST->{ $missing }, "$missing" );
    is( $MANIFEST->{ $missing }, 0, "MANIFEST did not declare: $missing" );
}

SKIP: {
    1 while unlink 'MANIFEST';
    -f 'MANIFEST' and skip "Unable to unlink MANIFEST: $!", 2;

    my $MANIFEST = check_MANIFEST( './' );
    
    isa_ok( $MANIFEST, 'HASH', "Returns:" );
    is( keys %$MANIFEST, 0, "Empty, so we get the ok" );
}

END { 
    1 while unlink 'MANIFEST';
    chdir File::Spec->updir
        if File::Spec->catdir( File::Spec->updir, 't' );
}
