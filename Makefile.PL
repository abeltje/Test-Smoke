use strict;
use 5.004;
use ExtUtils::MakeMaker;
use Config;

use File::Spec;
use Cwd;
use File::Path;


warn "\n'Makefile.PL' no longer configures your perl core smoke suite!!!\n" .
     "Please use:\n\tperl configsmoke.pl\n\n";


my %install = ( );
unless ( @ARGV ) {
    my $dft_install = File::Spec->catdir( File::Spec->updir, 'smoke' );
    $dft_install = File::Spec->rel2abs( $dft_install );

    my $install_dir = dir_prompt( 
        "Where would you like to install Test::Smoke?\n",
        $dft_install
    );

    %install = ( PREFIX => $install_dir, INSTALLSCRIPT => $install_dir,
                 LIB   => File::Spec->catdir( $install_dir, 'lib' ) );
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
		     },
    PREREQ_PM     => { 'File::Spec' => 0.82, 'Test::More' => 0},
    EXE_FILES     => [qw( synctree.pl patchtree.pl mailrpt.pl W32Configure.pl
                          mktest.pl mkovz.pl smoke.sh smokew32.bat
                          configsmoke.pl smokeperl.pl
                          smoke.cfg perl56x.cfg perlcurrent.cfg w32current.cfg
                          smoke56x_dfconfig smoke58x_dfconfig
                     )],
#    SKIP          => [qw( install )],
    %install
);

sub dir_prompt {

    GETDIR: {
        my $dir = &prompt;

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
        File::Path::rmtree( $dir ) unless $dir_existed;
        chdir $cwd or die "Cannot chdir($cwd) back: $!";

        print "Got [$dir]\n";
        return $dir;
    }
}
