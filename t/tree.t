#! /usr/bin/perl -w
use strict;

use Data::Dumper;
require File::Spec;
use File::Find;

use Test::More tests => 14;

# We need to test SourceTree.pm
sub MANIFEST_from_dir($) {
    my( $path ) = @_;
    my @files;
    find sub {
        -f or return;
        my $relfile = File::Spec->abs2rel( $File::Find::name, $path );
        my( undef, $dirs, $file ) = File::Spec->splitpath( $relfile );
        my @dirs = grep length $_ => File::Spec->splitdir( $dirs );
        push @dirs, $file;
        push @files, join '/', @dirs;
    }, $path;

    my $mani_file = File::Spec->catfile( $path, 'MANIFEST' );
    local *MANIFEST;
    open MANIFEST, "> $mani_file" or die "Can't create '$mani_file': $!";
    print MANIFEST "$_\n" for grep length $_ => @files, 'MANIFEST';
    close MANIFEST;
}

BEGIN { use_ok( 'Test::Smoke::SourceTree', ':const' ); }

my $path = File::Spec->rel2abs( 't' );
{
    my $tree = Test::Smoke::SourceTree->new( 't' );
    isa_ok( $tree, 'Test::Smoke::SourceTree' );

    is( $tree->canonpath, File::Spec->canonpath( $path ) , "canonpath" );

    is( $tree->rel2abs, $path, "rel2abs" );
    my $rel = File::Spec->abs2rel( File::Spec->rel2abs( 't' ) );
    is( $tree->abs2rel, $rel, "abs2rel" );

    is( $tree->mani2abs( 'win32/Makefile' ),
        File::Spec->catfile( $path, split m|/|, 'win32/Makefile' ),
        "mani2abs complex" );

}

SKIP: {
    eval { MANIFEST_from_dir 't' };
    $@ and skip $@, 4;

    my $tree = Test::Smoke::SourceTree->new( 't' );
    isa_ok( $tree, 'Test::Smoke::SourceTree' );

    my $mani_check = $tree->check_MANIFEST;

    is( keys %$mani_check, 1, "One dubious file" );
    ok( exists $mani_check->{ '.patch' }, "It is .patch" );

    my $mani_file = File::Spec->catfile( $tree->canonpath, 'MANIFEST' );

    is( $tree->abs2mani( $mani_file ), 'MANIFEST', "abs2mani" );
    1 while unlink $mani_file;
}

SKIP: { # Check that we can pass extra files to check_MANIFEST()
    eval { MANIFEST_from_dir 't' };
    $@ and skip $@, 4;

    my $tree = Test::Smoke::SourceTree->new( 't' );

    my $mani_check = $tree->check_MANIFEST( 'does_not_exist' );

    is( keys %$mani_check, 2, "Two dubious file" );
    ok( exists $mani_check->{does_not_exist}, "It is the extra file" );

    my $mani_file = File::Spec->catfile( $tree->canonpath, 'MANIFEST' );
    1 while unlink $mani_file;
}

{ # check new() croak()s without an argument

#line 200
    my $tree = eval { Test::Smoke::SourceTree->new() };
    ok( $@, "new() must have arguments" );
    like( $@, "/Usage:.*?at \Q$0\E line 200/", "it croak()s alright" );
}
