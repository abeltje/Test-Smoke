#! perl -w
use strict;

# $Id$

use File::Spec;

use Test::More tests => 61;
BEGIN { use_ok( 'Test::Smoke::Util' ); }
END { 
    1 while unlink 'win32/smoke.mk';
    chdir File::Spec->updir
        if -d File::Spec->catdir( File::Spec->updir, 't' );
}

chdir 't' or die "chdir: $!" if -d 't';

my $smoke_mk = 'win32/smoke.mk';

# Force the options that have a different default in
# the makefile.mk and in Configure_win32()
my $dft_args =  '-Duseithreads -Duselargefiles';
my $config   = $dft_args .
               ' -DINST_VER=\5.9.0 -DINST_ARCH=\$(ARCHNAME)';
Configure_win32( './Configure ' . $config, 'nmake' );

ok( -f $smoke_mk, "New makefile ($config)" );
my $extra_len = length( "\t\tconfig_args=$dft_args\t~\t\\\n" );
is( -s 'win32/Makefile', (-s $smoke_mk ) - $extra_len,
    "Sizes are equal for standard options (-Duseithreads)" );

# Now we can start testing this stuff
ok( unlink( $smoke_mk ), "Remove makefile" );

$config =  '-DINST_DRV=F:';
Configure_win32( './Configure ' . $config, 'nmake' );
ok( -f $smoke_mk, "New makefile ($config)" );

SKIP: {
    local *MF;
    ok open( MF, "< $smoke_mk" ), "Opening makefile"  or
        skip "Can't read from '$smoke_mk': $!", 7;
    my $makefile = do { local $/; <MF> };
    close MF;

    # This should be set
    like( $makefile, '/^INST_DRV\s*=\s*F:\n/m', '$(INST_DRV)' );
    like( $makefile, '/^INST_DRV\t= untuched\n/m', "Untuched 1" );
    like( $makefile, '/^# INST_DRV\t= untuched\n/m', "Untuched 2" );

    #These should be unset
    like( $makefile, '/^#USE_MULTI\s*= define\n/m', '#$(USE_MULTI)' );
    like( $makefile, '/^#USE_ITHREADS\s*= define\n/m', '#$(USE_ITHREADS)' );
    like( $makefile, '/^#USE_IMP_SYS\s*= define\n/m', '#$(USE_IMP_SYS)' );
    like( $makefile, '/^#USE_LARGE_FILES\s*= define\n/m',
          '#$(USE_LARGE_FILES)' );
}

# Here we test the setting of CCTYPE
ok( unlink( $smoke_mk ), "Remove makefile" );

$config = '-DCCTYPE=MSVC60';
Configure_win32( './Configure ' . $config, 'nmake' );
ok( -f $smoke_mk, "New makefile ($config)" );

SKIP: {
    local *MF;
    ok open( MF, "< $smoke_mk" ), "Opening makefile"  or
        skip "Can't read from '$smoke_mk': $!", 5;
    my $makefile = do { local $/; <MF> };
    close MF;

    # This should now be set twice
    like( $makefile, '/^CCTYPE\s*= MSVC60\nCCTYPE\s*= MSVC60\n/m',
          '$(CCTYPE) set twice' );
    like( $makefile, '/^\s*CCTYPE=\$\(CCTYPE\) > somewhere\n/m',
          "Untuched CCTYPE" );

    #These should be unset
    like( $makefile, '/^#USE_MULTI\s*= define\n/m', '#$(USE_MULTI)' );
    like( $makefile, '/^#USE_ITHREADS\s*= define\n/m', '#$(USE_ITHREADS)' );
    like( $makefile, '/^#USE_IMP_SYS\s*= define\n/m', '#$(USE_IMP_SYS)' );
}

# Check that all three are set for -Duseithreads
ok( unlink( $smoke_mk ), "Remove makefile" );

$config = '-Dusethreads';
Configure_win32( './Configure ' . $config, 'nmake' );
ok( -f $smoke_mk, "New makefile ($config)" );

SKIP: {
    local *MF;
    ok open( MF, "< $smoke_mk" ), "Opening makefile"  or
        skip "Can't read from '$smoke_mk': $!", 3;
    my $makefile = do { local $/; <MF> };
    close MF;

    #These should be set
    like( $makefile, '/^USE_MULTI\s*= define\n/m', '$(USE_MULTI) set' );
    like( $makefile, '/^USE_ITHREADS\s*= define\n/m', '$(USE_ITHREADS) set' );
    like( $makefile, '/^USE_IMP_SYS\s*= define\n/m', '$(USE_IMP_SYS) set' );
}

# This will be a full configuration:
ok( unlink( $smoke_mk ), "Remove makefile" );

$config = '-Duselargefiles';
Configure_win32( './Configure ' . $config, 'nmake' );
ok( -f $smoke_mk, "New makefile ($config)" );

SKIP: {
    local *MF;
    ok open( MF, "< $smoke_mk" ), "Opening makefile"  or
        skip "Can't read from '$smoke_mk': $!", 1;
    my $makefile = do { local $/; <MF> };
    close MF;

    #These should be set
    like( $makefile, '/^USE_LARGE_FILES\s*= define\n/m',
          '$(USE_LARGE_FILES) set' );
}

# This will be a full configuration:
ok( unlink( $smoke_mk ), "Remove makefile" );

$config = '-des -Dusedevel -Duseithreads -Dusemymalloc ' .
          '-DCCTYPE=MSVC60 -Dcf_email=abeltje@cpan.org';
Configure_win32( './Configure ' . $config, 'nmake' );
ok( -f $smoke_mk, "New makefile ($config)" );

SKIP: {
    local *MF;
    ok open( MF, "< $smoke_mk" ), "Opening makefile"  or
        skip "Can't read from '$smoke_mk': $!", 3;
    my $makefile = do { local $/; <MF> };
    close MF;

    #These should be set
    like( $makefile, '/^USE_MULTI\s*= define\n/m', '$(USE_MULTI) set' );
    like( $makefile, '/^USE_ITHREADS\s*= define\n/m', '$(USE_ITHREADS) set' );
    like( $makefile, '/^USE_IMP_SYS\s*= define\n/m', '$(USE_IMP_SYS) set' );
    like( $makefile, '/^\s*PERL_MALLOC\s*= define\n/m', '$(PERL_MALLOC) set' );
    like( $makefile, '/^EMAIL\s*= abeltje\@cpan\.org\n/m', '$(EMAIL) set' );

    # This should now be set twice
    like( $makefile, '/^CCTYPE\s*= MSVC60\nCCTYPE\s*= MSVC60\n/m', 
          '$(CCTYPE) set twice' );
    like( $makefile, '/^\s*CCTYPE=\$\(CCTYPE\) > somewhere\n/m', 
          "Untuched CCTYPE" );
}

ok( unlink( $smoke_mk ), "Remove makefile" );

$config = '-des -Dusedevel';
my @cfg_args = ( 'osvers=5.0 W2000Pro' );

Configure_win32( './Configure ' . $config, 'nmake', @cfg_args );
ok( -f $smoke_mk, "New makefile ($config/[@cfg_args])" );

SKIP: {
    local *MF;
    ok open( MF, "< $smoke_mk" ), "Opening makefile"  or
        skip "Can't read from '$smoke_mk': $!", 1;
    my $makefile = do { local $/; <MF> };
    close MF;

    like( $makefile, '/
          ^CFG_VARS \s* = \s* \\\\\n
           \s*"osvers=5\.0\ W2000Pro"\t+\\\\\n
           \s*"config_args=-Dusedevel"\t+\\\\\n
           \s*"INST_DRV=
    /mx', "CFG_VARS macro for Config.pm" );
}

ok( unlink( $smoke_mk ), "Remove makefile" );

$config = '-des -Dusedevel';
@cfg_args = ( 'osvers=5.0 W2000Pro', "", 'ccversion=cl 6.0' );

Configure_win32( './Configure ' . $config, 'nmake', @cfg_args );
ok( -f $smoke_mk, "New makefile ($config/[@cfg_args])" );

SKIP: {
    local *MF;
    ok open( MF, "< $smoke_mk" ), "Opening makefile"  or
        skip "Can't read from '$smoke_mk': $!", 1;
    my $makefile = do { local $/; <MF> };
    close MF;

    like( $makefile, '/
          ^CFG_VARS \s* = \s* \\\\\n
           \s*"osvers=5\.0\ W2000Pro"\t+\\\\\n
           \s*"ccversion=cl\ 6\.0"\t+\\\\\n
           \s*"config_args=-Dusedevel"\t+\\\\\n
           \s*"INST_DRV=
    /mx', "CFG_VARS macro for Config.pm" );
}

ok( unlink( $smoke_mk ), "Remove makefile" );

$config = '-des -Dusedevel';
@cfg_args = ( 'osvers=5.0 W2000Pro', "trash", 'ccversion=cl 6.0' );

Configure_win32( './Configure ' . $config, 'nmake', @cfg_args );
ok( -f $smoke_mk, "New makefile ($config/[@cfg_args])" );

SKIP: {
    local *MF;
    ok open( MF, "< $smoke_mk" ), "Opening makefile"  or
        skip "Can't read from '$smoke_mk': $!", 1;
    my $makefile = do { local $/; <MF> };
    close MF;

    like( $makefile, '/
          ^CFG_VARS \s* = \s* \\\\\n
           \s*"osvers=5\.0\ W2000Pro"\t+\\\\\n
           \s*"ccversion=cl\ 6\.0"\t+\\\\\n
           \s*"config_args=-Dusedevel"\t+\\\\\n
           \s*"INST_DRV=
    /mx', "CFG_VARS macro for Config.pm" );
}

ok( unlink( $smoke_mk ), "Remove makefile" );

$config = $dft_args . " -Accflags='-DPERL_COPY_ON_WRITE'";
Configure_win32( './Configure '. $config, 'nmake' );
ok( -f $smoke_mk, "New makefile ($config)" );
SKIP: {
    local *MF;
    ok open(MF, "< $smoke_mk"), "Opening makefile" or
        skip "Cannot read from '$smoke_mk': $!", 1;
    my $makefile = do { local $/; <MF> };
    close MF;

    like( $makefile, '/^BUILDOPT\t=\s\$\(BUILDOPT\)\ -DPERL_COPY_ON_WRITE\n
                       #+\ CHANGE THESE ONLY IF YOU MUST\ #+
    /mx', "-Accflags= is translated to BUILDOPT = \$(BUILDOPT)" );
}

ok( unlink( $smoke_mk ), "Remove makefile" );

$config = $dft_args . " -Accflags='-DPERL_COPY_ON_WRITE'".
                      " -Accflags='-DPERL_POLLUTE'";
Configure_win32( './Configure '. $config, 'nmake' );
ok( -f $smoke_mk, "New makefile ($config)" );
SKIP: {
    local *MF;
    ok open(MF, "< $smoke_mk"), "Opening makefile" or
        skip "Cannot read from '$smoke_mk': $!", 1;
    my $makefile = do { local $/; <MF> };
    close MF;

    like( $makefile, '/^BUILDOPT\t=\s\$\(BUILDOPT\)\ -DPERL_COPY_ON_WRITE\n
                        BUILDOPT\t=\s\$\(BUILDOPT\)\ -DPERL_POLLUTE\n
                        #+\ CHANGE THESE ONLY IF YOU MUST\ #+
    /mx', "-Accflags= is translated to BUILDOPT = \$(BUILDOPT)" );
}
