#! /usr/bin/perl -w
# $Id$
use strict;
use 5.004;
use ExtUtils::MakeMaker;
use Config;

use File::Spec;
use Cwd;
use File::Path;

# Some strange stuff happens when WriteMakefile() is called
# on a non-clean distribution, cleanup before
my $devnull = File::Spec->devnull;
system "$Config{make} -i distclean >$devnull 2>&1";

my %install = ( );
unless ( @ARGV ) {
    my $dft_install = File::Spec->catdir( File::Spec->updir, 'smoke' );
    $dft_install = File::Spec->rel2abs( $dft_install );

    my $install_dir = dir_prompt( 
        "Where would you like to install Test::Smoke?\n",
        $dft_install
    );

    %install = ( PREFIX => $install_dir, INSTALLSCRIPT => $install_dir,
#                 LIB   => File::Spec->catdir( $install_dir, 'lib' ) );
                 LIB   => $install_dir );
}

WriteMakefile(
    NAME	  => "Test-Smoke",
    DISTNAME	  => "Test-Smoke",
    VERSION_FROM  => "lib/Test/Smoke.pm",
    $] >= 5.005 ? (
    AUTHOR	  => 'H.Merijn Brand <h.m.brand@hccnet.nl>, '.
		     'Nicholas Clark <nick@plum.flirble.org> and ' .
                     'Abe Timmerman <abeltje@cpan.org>',
    ABSTRACT_FROM => 'lib/Test/Smoke.pm',
    ) : (),

    dist	  => { COMPRESS => "gzip -9f",
                       SUFFIX   => ".gz",
                       PREOP    => "cpansign -s",
		     },
    PREREQ_PM     => { 'File::Spec' => 0.82, 'Test::More' => 0},
    PMLIBDIRS     => [ File::Spec->curdir ],
    EXE_FILES     => [qw( synctree.pl patchtree.pl mailrpt.pl W32Configure.pl
                          mktest.pl mkovz.pl smoke.sh smokew32.bat
                          configsmoke.pl smokeperl.pl runsmoke.pl
                          archiverpt.pl smokestatus.pl )],
    %install
);

sub MY::libscan {
    my( $self, $path ) = @_;
    return m:\.svn\b|\bt\b|\bprivate\b: ? "" : $path;
}

sub dir_prompt {

    GETDIR: {
        my $dir = &prompt; # & -> pass @_

        # thanks to perlfaq5
        $dir =~ s{^ ~ ([^/]*)}
                 {$1 ? ( getpwnam $1 )[7] : 
                       ( $ENV{HOME} || $ENV{LOGDIR} || 
                         "$ENV{HOMEDRIVE}$ENV{HOMEPATH}" )}ex;

        my $cwd = cwd();
        my $dir_existed = -d $dir;
        File::Path::mkpath( $dir, 1, 0755 ) unless $dir_existed;
        chdir $dir or warn "Cannot chdir($dir): $!\n" and redo GETDIR;
        $dir = File::Spec->canonpath( cwd() );
        chdir $cwd or warn "Cannot chdir($cwd) back: $!\n";
        File::Path::rmtree( $dir ) unless $dir_existed;

        print "Got [$dir]\n";
        return $dir;
    }
}
