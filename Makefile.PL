#! /usr/bin/perl -w
# $Id$
use strict;
use 5.004;
use ExtUtils::MakeMaker;
use Config;

my $findbin;
use File::Basename;
BEGIN { $findbin = dirname $0 }
use File::Spec::Functions qw( :DEFAULT rel2abs );
use Cwd;
use File::Path;

# Some strange stuff happens when WriteMakefile() is called
# on a non-clean distribution, cleanup before
my $devnull = File::Spec->devnull;
my $hideout = $^O eq 'VMS' ? '' : ' >$devnull 2>&1';
system "$Config{make} -i distclean$hideout";

my %install = ( );
unless ( @ARGV ) {
    my $dft_install = exists $ENV{SMOKE_INSTDIR} && $ENV{SMOKE_INSTDIR} ne ""
        ? $ENV{SMOKE_INSTDIR}
        : catdir( updir(), 'smoke' );
    $dft_install = rel2abs( $dft_install );

    my $install_dir = dir_prompt( 
        "Where would you like to install Test::Smoke?\n",
        $dft_install
    );

    %install = ( PREFIX => $install_dir, INSTALLSCRIPT => $install_dir,
#                 LIB   => File::Spec->catdir( $install_dir, 'lib' ) );
                 LIB   => $install_dir );
}
my @scripts = qw( synctree.pl patchtree.pl mailrpt.pl W32Configure.pl
                  configsmoke.pl smokeperl.pl runsmoke.pl
                  archiverpt.pl smokestatus.pl );
-f catfile( $findbin, '.patch' ) and push @scripts, '.patch';

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
    PMLIBDIRS     => [ curdir() ],
    EXE_FILES     => \@scripts,
    %install
);

sub MY::libscan {
    my( $self, $path ) = @_;
    my @nopaths = qw( .svn t private investigate );
    my $patt = join '|', map {
        /^\w/ and $_ = "\\b$_";
        /\w$/ and $_ = "$_\\b";
        $_;
    } @nopaths;
    print "$path($patt):\n";
    print  "\t" . ($path =~ m:$patt: ? "" : $path) . "\n";
    return $path =~ m:$patt: ? "" : $path;
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
        $dir = canonpath( cwd() );
        chdir $cwd or warn "Cannot chdir($cwd) back: $!\n";
        File::Path::rmtree( $dir ) unless $dir_existed;

        print "Got [$dir]\n";
        return $dir;
    }
}
