#! /usr/bin/perl -w
use strict;

# $Id$

use File::Spec;
my $findbin;
use File::Basename;
BEGIN { $findbin = dirname $0; }
use lib $findbin;
use TestLib;

use Test::More tests => 30;
BEGIN { use_ok( 'Test::Smoke::Util', 'get_smoked_Config' ) }

# make it work for all
require POSIX;
my( $osname, undef, $osvers, undef, $arch ) = map lc $_ => POSIX::uname();
my $version = '5.9.0';
my $config_sh = <<"!END!";
osname='$osname'
osvers='$osvers'
archname='$arch'
cf_email='abeltje\@cpan.org'
version='$version'
!END!

my( $Config_heavy, $Config_pm, $Config_sh );
SKIP: {
    my $cfg_nm = 'Config_heavy.pl';
    my $to_skip = 5;
    my $libpath = File::Spec->catdir( $findbin, 'lib' );
    -d $libpath or mkpath( $libpath )  or 
        skip "Can't create '$libpath': $!", $to_skip;
    $Config_heavy = File::Spec->catfile( $libpath, $cfg_nm );

    local *CONFIGPM;
    open CONFIGPM, "> $Config_heavy" or 
        skip "Can't create '$Config_heavy': $!", $to_skip;

    print CONFIGPM <<EOCONFIG;
package Config;

# blah blah
local \*_ = \\my \$a;
\$_ = \<\<'!END!';
$config_sh
!END!

# more stuff
1;
EOCONFIG
    close CONFIGPM or skip "Error '$Config_heavy': $!", $to_skip;

    my %Config = get_smoked_Config( $findbin,
                                    qw( archname cf_email version
                                        osname osvers ));

    ok( -e $Config_heavy, "Config from: $Config_heavy" );
    is( $Config{archname}, $arch, "Architecture $arch" );
    is( $Config{cf_email}, 'abeltje@cpan.org', 'cf_email' );
    is( $Config{osname}, $osname, "OS name: $osname" );
    is( $Config{osvers}, $osvers, "OS version: $osvers" );
    is( $Config{version}, $version, "Perl version: $version" );

    1 while unlink $Config_heavy;
}

SKIP: {
    my $to_skip = 5;
    my $libpath = File::Spec->catdir( $findbin, 'lib' );
    -d $libpath or mkpath( $libpath )  or 
        skip "Can't create '$libpath': $!", $to_skip;
    $Config_pm = File::Spec->catfile( $libpath, 'Config.pm' );

    local *CONFIGPM;
    open CONFIGPM, "> $Config_pm" or 
        skip "Can't create '$Config_pm': $!", $to_skip;

    print CONFIGPM <<EOCONFIG;
package Config;

# blah blah
my \$config_sh = \<\<'!END!';
$config_sh
!END!

# more stuff
1;
EOCONFIG
    close CONFIGPM or skip "Error '$Config_pm': $!", $to_skip;

    my %Config = get_smoked_Config( $findbin,
                                    qw( archname cf_email version
                                        osname osvers ));

    ok( -e $Config_pm, "Config from: $Config_pm" );
    is( $Config{archname}, $arch, "Architecture $arch" );
    is( $Config{cf_email}, 'abeltje@cpan.org', 'cf_email' );
    is( $Config{osname}, $osname, "OS name: $osname" );
    is( $Config{osvers}, $osvers, "OS version: $osvers" );
    is( $Config{version}, $version, "Perl version: $version" );

    1 while unlink $Config_pm;
}

SKIP: { # get info from config.sh
    my $to_skip = 5;
    my $libpath = File::Spec->catdir( $findbin );
    $Config_sh = File::Spec->catfile( $libpath, 'config.sh' );

    local *CONFIGSH;
    open CONFIGSH, "> $Config_sh" or 
        skip "Can't create '$Config_sh': $!", $to_skip;

    print CONFIGSH <<EOCONFIG;
#!/bin/sh
#
# This file is produced by $0
#

# Package name      : perl 5
# Configuration time: @{[ scalar localtime ]}


$config_sh
EOCONFIG
    close CONFIGSH or skip "Error '$Config_sh': $!", $to_skip;

    my %Config = get_smoked_Config( $findbin,
                                    qw( archname cf_email version
                                        osname osvers ));

    ok( -e $Config_sh, "Config from: $Config_sh" );
    is( $Config{archname}, $arch, "Architecture $arch" );
    is( $Config{cf_email}, 'abeltje@cpan.org', 'cf_email' );
    is( $Config{osname}, $osname, "OS name: $osname" );
    is( $Config{osvers}, $osvers, "OS version: $osvers" );
    is( $Config{version}, $version, "Perl version: $version" );

    1 while unlink $Config_sh;
}

{
    my %Config = get_smoked_Config( $findbin,
                                    qw( archname cf_email version
                                        osname osvers ));

    my $no_files = 1;
    $no_files &&= ! -e $_ for grep defined $_
        => ( $Config_heavy, $Config_pm, $Config_sh );
    ok( $no_files, "Config from: fallback" ); 
    is( $Config{archname}, $arch, "Architecture $arch" );
    is( $Config{osname}, $osname, "OS name: $osname" );
    is( $Config{osvers}, $osvers, "OS version: $osvers" );
    is( $Config{version}, '5.?.?', "Perl version: $Config{version}" );
}

SKIP: {
    my $to_skip = 5;

    local *CONFIGPM;
    open CONFIGPM, "> $Config_pm" or 
        skip "Can't create '$Config_pm': $!", $to_skip;

    print CONFIGPM <<EOCONFIG;
package Config;

# Change 23147 messed all up!
local \*_ = \\my \$a;
\$_ = \<\<'!END!';
$config_sh
!END!

s/(byteorder=)(['"]).*?\\2/\$1\$2\$byteorder\$2/m; # emacs '
our \$Config_SH : unique = \$_;
# more stuff
1;
EOCONFIG
    close CONFIGPM or skip "Error '$Config_pm': $!", $to_skip;

    my %Config = get_smoked_Config( $findbin,
                                    qw( archname cf_email version
                                        osname osvers ));

    ok( -e $Config_pm, "Config from: $Config_pm" );
    is( $Config{archname}, $arch, "Architecture $arch" );
    is( $Config{cf_email}, 'abeltje@cpan.org', 'cf_email' );
    is( $Config{osname}, $osname, "OS name: $osname" );
    is( $Config{osvers}, $osvers, "OS version: $osvers" );
    is( $Config{version}, $version, "Perl version: $version" );

    1 while unlink $Config_pm;
}


END {
    rmtree( File::Spec->catdir( $findbin, 'lib' ) )
}
