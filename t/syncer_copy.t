#! /usr/bin/perl -w
use strict;

# $Id$

use FindBin;
use lib $FindBin::Bin;
use TestLib;
use File::Spec;

use Test::More;

my $cdir = 'origdir';
my $ddir = 'perl-current';
# Set up some sort of source-tree
require File::Copy;

SETUP: {
    chdir 't' or plan skip_all => "Cannot chdir 't': $!";
    # Make sure they are all gone
    rmtree( $cdir );
    rmtree( $ddir );

    mkdir $cdir, 0744 or plan skip_all => "Cannot create test-tree: $!";
    # Copy all *.t files to the new dir
    foreach my $test ( glob '*.t' ) {
        File::Copy::copy( $test, File::Spec->catfile( $cdir, $test ) );
    }
    # Copy the subdir 'win32' also
    my $subdir = File::Spec->catdir( $cdir, 'win32' );
    mkdir $subdir, 0744 or plan skip_all => "Cannot create '$subdir': $!";
    local *DIR;
    opendir DIR, 'win32' or plan skip_all => "Cannot opendir 'win32': $!";
    while ( my $file = readdir DIR ) {
        -f File::Spec->catfile('win32', $file ) or next;
        File::Copy::copy( File::Spec->catfile( 'win32', $file ),
                          File::Spec->catfile( $subdir, $file ) );
    }
    closedir DIR;
    # Create a '.patch'
    local *DOTPATCH;
    my $dot_patch = File::Spec->catfile( $cdir, '.patch' );
    open DOTPATCH, "> $dot_patch" or
        plan skip_all => "Cannot create '.patch': $!";
    print DOTPATCH "20000\n";
    close DOTPATCH or plan skip_all => "Cannot write '.patch': $!";
    # Create a 'MANIFEST'
    my @MANIFEST = map manify_path( $_ ) => ( 'MANIFEST', get_dir( $cdir ) );
    local *MANIFEST;
    my $manifest = File::Spec->catfile( $cdir, 'MANIFEST' );
    open MANIFEST, "> $manifest" or
        plan skip_all => "Cannot create 'MANIFEST': $!";
    print MANIFEST "$_\n" for @MANIFEST;
    close MANIFEST or plan skip_all => "Cannot write 'MANIFEST': $!";
    chdir File::Spec->updir;
}

plan tests => 8;
use_ok( 'Test::Smoke::Syncer' );
require_ok( 'Test::Smoke::SourceTree' );

chdir 't';
SKIP: {
    my $syncer = Test::Smoke::Syncer->new( copy => { v => 0,
        ddir => $ddir,
        cdir => $cdir, 
    } );

    isa_ok( $syncer, 'Test::Smoke::Syncer' );
    isa_ok( $syncer, 'Test::Smoke::Syncer::Copy' );

    my $patch = $syncer->sync;
    is( $patch, 20000, "Patchlevel after copy: $patch" );

    my %orig = map { $_ => 1 } get_dir( $cdir );
    my %dest = map { $_ => 1 } get_dir( $ddir );

    is_deeply( \%orig, \%dest, "directories compare ok" );

    # same thing really
    foreach my $key ( keys %orig ) {
        $orig{ $key } = $dest{ $key } = 0 if exists $dest{ $key };
    }
    my $ocnt = grep $orig{ $_ } => keys %orig;
    is( $ocnt, 0, "All files seem to be copied" );
    my $dcnt = grep $dest{ $_ } => keys %dest;
    is( $dcnt, 0, "No other files have been added" );
}

END { 
    unless ( $ENV{SMOKE_DEBUG} ) {
      rmtree( $ddir );
      rmtree( $cdir );
    }
    chdir File::Spec->updir;
}
