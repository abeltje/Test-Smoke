#! /usr/bin/perl -w
use strict;

use File::Spec;
use FindBin;
use lib $FindBin::Bin;
use TestLib;
use Cwd;

use Test::More tests => 30;

use_ok( 'Test::Smoke::Patcher' );

{
    my $tdir = 't';
    my $fs_tdir = File::Spec->rel2abs( $tdir );
    my $patcher = Test::Smoke::Patcher->new( single => { ddir  => $tdir } );
    isa_ok( $patcher, 'Test::Smoke::Patcher' );
    is( $patcher->{ddir}, $fs_tdir, "destination dir ($fs_tdir)" );
    is( $patcher->{pfile}, undef, "pfile attribute undef" );
    is( $patcher->{patch}, 'patch', "patch attribute" );
    is( $patcher->{popts}, '', "popts attribute empty" );
    is( $patcher->{v}, 0, "v attribute is zero" );

    # now test the options stuff
    $patcher->{popts} = '-bp1';
    is( $patcher->_make_opts, '-bp1', "Patch option '-bp1'" );
}

my $patch = whereis( 'patch' );
my $testpatch = File::Spec->catfile( 't', 'test.patch' );

SKIP: { # test Test::Smoke::Patcher->patch_single()
    my $to_skip = 13;
    skip "Cannot find a working 'patch' program.", $to_skip unless $patch;
    my $patcher = Test::Smoke::Patcher->new( single => { v => 0,
        -ddir  => File::Spec->catdir( 't', 'perl' ),
        -patch => $patch,
    });

    isa_ok( $patcher, 'Test::Smoke::Patcher' );
    my $untgz = find_untargz() or skip "Cannot un-tar-gz", --$to_skip;
    my $unzipper = find_unzip() or skip "No unzip found", $to_skip;

    chdir('t');
    my $untgz_ok = do_untargz( $untgz, File::Spec->catfile(
        qw( ftppub snap perl@20000.tgz ) ) );
    chdir( File::Spec->updir );

    my $p_content = do_unzip( $unzipper, File::Spec->catfile(
        qw(t ftppub perl-current-diffs 20001.gz ) ));

    ok( $untgz, "I found untar-gz ($untgz)");
    ok( $unzipper, "We have unzip ($unzipper)" );
    ok( $untgz_ok, "Mockup sourcetree" );
    ok( $p_content, "The patch was read..." );

    # check if it works for passing the patch as a ref2scalar
    eval { $patcher->patch_single( \$p_content ) };
    ok( ! $@, "patch applied (SCALAR ref): $@" );

    my $newfile = get_file(qw( t perl patchme.txt ));
    like( $newfile, '/^VERSION == 20001$/m', "Content seems ok" );

    my $reverse1 = File::Spec->catfile( File::Spec->updir, 'test.patch' );
    local *MYPATCH;
    open MYPATCH, "> $testpatch" or 
        skip "Cannont create '$testpatch': $!", $to_skip -= 4;
    binmode MYPATCH;
    print MYPATCH $p_content;
    close MYPATCH;

    eval{ $patcher->patch_single( $reverse1, '-R' ) };
    ok( !$@, "Reverse patch applied (filename): $@" );
    $newfile = get_file(qw( t perl patchme.txt ));
    unlike( $newfile, '/^VERSION == 20001$/m', "Content seems ok" );

    my @plines = map "$_\n" => split /\n/, $p_content;
    eval { $patcher->patch_single( \@plines ) };
    ok( !$@, "Patch reapplied (ARRAY ref): $@" );
    $newfile = get_file(qw( t perl patchme.txt ));
    like( $newfile, '/^VERSION == 20001$/m', "Content seems ok" );

    open MYPATCH, "< $testpatch" or
        skip "Cannot open '$testpatch': $!", $to_skip -= 4;
    eval { $patcher->patch_single( \*MYPATCH, '-R' ) };
    ok( ! $@, "Reverse patch applied (GLOB ref): $@" );
    close MYPATCH;
    $newfile = get_file(qw( t perl patchme.txt ));
    unlike( $newfile, '/^VERSION == 20001$/m', "Content seems ok" );

}

SKIP: { # Test multi mode
    my $to_skip = 9;

    skip "No patch program or test-patch found", $to_skip
        unless $patch && -e $testpatch;

    my $relpatch = File::Spec->catfile( File::Spec->updir, 'test.patch' );
    my $pi_content = "$relpatch\n";

    my $patcher = Test::Smoke::Patcher->new( multi => { v => 0,
        ddir  => File::Spec->catdir( 't', 'perl' ),
        patch => $patch,
    });
    isa_ok( $patcher, 'Test::Smoke::Patcher' );

    eval { $patcher->patch_multi( \$pi_content ) };
    ok( !$@, "No error while running patch $@" );
    my $newfile = get_file(qw( t perl patchme.txt ));
    like( $newfile, '/^VERSION == 20001$/m', "Content ok" );

    my @patches = map "$_\n" => ( "$relpatch;-R", $relpatch, "$relpatch;-R" );
    eval { $patcher->patch_multi( \@patches ) };
    ok( ! $@, "No error while running patch $@" );
    $newfile = get_file(qw( t perl patchme.txt ));
    unlike( $newfile, '/^VERSION == 20001$/m', "Content ok" );

    my $pinfo = File::Spec->catfile( 't', 'test.patches' );
    local *PINFO;
    open PINFO, "+> $pinfo" or skip "Cannot open '$pinfo': $!", $to_skip -= 5;
    select( (select(PINFO), $|++)[0] );
    print PINFO <<EOPINFO;
$relpatch
# Do some somments 
# This is to take out #20001, so we can see what happend
$relpatch;-R
$relpatch
EOPINFO
    seek PINFO, 0, 0;
    eval { $patcher->patch_multi( \*PINFO ) };
    ok( ! $@, "No Errors while running patch $@" );
    $newfile = get_file(qw( t perl patchme.txt ));
    like( $newfile, '/^VERSION == 20001$/m', "Conent OK" );
    close PINFO;
    1 while unlink $pinfo;

    open PINFO, "> $pinfo" or skip "Cannot open '$pinfo': $!", $to_skip -= 2;
    print PINFO "$relpatch;-R\n";
    close PINFO or skip "Error on write: $!", $to_skip;

    eval { $patcher->patch_multi( File::Spec->rel2abs($pinfo) ) };
    ok( ! $@, "No Errors while running patch $@" );
    $newfile = get_file(qw( t perl patchme.txt ));
    unlike( $newfile, '/^VERSION == 20001$/m', "Conent OK" );
    1 while unlink $pinfo;
}

END {
    rmtree( File::Spec->catdir(qw( t perl )) );
    1 while unlink $testpatch;
}
