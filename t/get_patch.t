#! perl -w
use strict;

# $Id$

use File::Spec;

use Test::More tests => 4;
BEGIN { use_ok( 'Test::Smoke::Util' ); }

chdir 't' or die "chdir: $!" if -d 't';
my $snap_level = 17888;

SKIP: {
    # better safe; try and unlink '.patch'
    1 while unlink '.patch';
    -f '.patch' and skip "Can't unlink '.patch'", 1;

    local *PL;
    open PL, '> patchlevel.h' or skip "Couldn't crate patchlevel.h: $!", 1;
    printf PL <<'EO_PATCHLEVEL', $snap_level;
#if !defined(PERL_PATCHLEVEL_H_IMPLICIT) && !defined(LOCAL_PATCH_COUNT)
static  char    *local_patches[] = {
        NULL
        ,"DEVEL%d"
        ,NULL
};
EO_PATCHLEVEL
    close PL or skip 1, "Couldn't close patchlevel.h: $!";

    my $get_patch = get_patch();

    is( $get_patch, "$snap_level(+)", "Found snaplevel: $get_patch" );
}

SKIP: {
    my $patch = 17999;
    local *PL;
    open( PL, '> .patch') or skip "Couldn't create .patch: $!", 1;
    print PL $patch;
    close PL or skip "Couldn't close .patch: $!", 1;

    my $get_patch = get_patch();
    is( $get_patch, $patch, "Found patchlevel: $patch" );

    1 while unlink '.patch';
}

SKIP: {
    1 while unlink '.patch';
    -f '.patch' and skip "Can't unlink '.patch'", 1;
    ( my $get_patch = get_patch() ) =~ tr/0-9//cd;
    is( $get_patch, $snap_level, "Found snaplevel(2): $get_patch" );
}

END { 
    1 while unlink 'patchlevel.h';
    chdir File::Spec->updir
        if -d File::Spec->catdir( File::Spec->updir, 't' );
}
