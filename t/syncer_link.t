#! /usr/bin/perl -w
use strict;

# $Id$

use File::Spec;
use lib File::Spec->rel2abs( 't' );
use TestLib;
use Test::More tests => 9;

use_ok( 'Test::Smoke::Syncer' );

{
    my $syncer = Test::Smoke::Syncer->new( hardlink => { v => 0,
        ddir => File::Spec->catdir(qw( t perl-current )),
        hdir => File::Spec->catdir(qw( t perl )),
    } );

    isa_ok( $syncer, 'Test::Smoke::Syncer' );
    isa_ok( $syncer, 'Test::Smoke::Syncer::Hardlink' );
}

{ # check that is croak()s
#line 100
    my $syncer = eval { Test::Smoke::Syncer->new( hardlink => { v => 0,
        ddir => File::Spec->catdir(qw( t perl-current )),
    } ) };

    ok( $@, "croak on omitted {hdir}" );
    like( $@, "/No source-directory.*?at \Q$0\E line 100/", "It's a croak()" );
}

SKIP: {
# Try to find tar/gzip, Archive::Tar/Compress::Zlib
# When found, t/ftppub/snap/perl@20000.tgz can be extracted
# and used as a base for the hardlink sync

    my $to_skip = 2;
    my $tar = find_uncompress() or
        skip "Cannot find decompression stuff", $to_skip;

    do_uncompress( $tar, 't', 
                   File::Spec->catfile(qw( ftppub snap perl@20000.tgz )) ) or
        skip "Cannot decompress testsnapshot", $to_skip;

    ok( -d File::Spec->catdir(qw( t perl )), "snapshot OK" );

    my $syncer = Test::Smoke::Syncer->new( hardlink => { v=> 0,
        ddir => File::Spec->catdir(qw( t perl-current )),
        hdir => File::Spec->catdir(qw( t perl )),
    } );

    my %perl = map { ($_ => 1) } get_dir( $syncer->{hdir} );
    $syncer->sync();
    my %perl_current = map { ($_ => 1) } get_dir( $syncer->{ddir} );

    is( scalar keys %perl_current, scalar keys %perl,
        "number of files the same" );
    is_deeply( \%perl_current, \%perl, "Same files in the two dirs" );

    if ( $^O ne 'MSWin32' ) {
        is_deeply( inodes( $syncer->{ddir} ), inodes( $syncer->{hdir} ),
                   "check inodes of hardlinks" );
    } else {
        skip "Cannot check inodes on Windows-fs", 1;
    }

    rmtree( File::Spec->catdir(qw( t perl )), $syncer->{v} );
    rmtree( File::Spec->catdir(qw( t perl-current )), $syncer->{v} );
}

sub inodes {
    my $dir = shift;

    require File::Find;
    my %inodes;
    File::Find::find( sub {
        -f or return;
        $inodes{ (stat _)[1] } = 1;
    }, $dir );

    return \%inodes;
}

sub find_uncompress {
    return find_untargz;
}

sub do_uncompress {
    my( $tar, $ddir, $sfile ) = @_;

    chdir $ddir or do {
        warn "Cannot chdir($ddir): $!";
        return;
    };

    do_untargz( $tar, $sfile );

    # I cannot use Test::Smoke::Syncer::Snapshot to extract
    # but I need check_dot_patch() for the tests
    my $syncer = Test::Smoke::Syncer->new( snapshot => { 
        v    => 2,
        ddir => 'perl',
    });
    $syncer->check_dot_patch();

    chdir File::Spec->updir;

    return 1;
}
