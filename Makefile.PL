use 5.004;
use ExtUtils::MakeMaker;
use Config;

warn "\n'Makefile.PL' no longer configures your perl core smoke suite!!!\n" .
     "Please use:\n\tperl configsmoke.pl\n\n";

WriteMakefile(
    NAME	  => "Test-Smoke",
    DISTNAME	  => "Test-Smoke",
    VERSION_FROM  => "smokeperl.pl",
    $] >= 5.005 ? (
    AUTHOR	  => 'H.Merijn Brand <h.m.brand@hccnet.nl>, '.
		     'Nicholas Clark <nick@plum.flirble.org> and ' .
                     'Abe Timmerman <abeltje@cpan.org>',
#    ABSTRACT_FROM => 'smokeperl.pl',
    ) : (),

    dist	  => { COMPRESS => "gzip -9f",
                       SUFFIX   => ".gz",
		     },
    PREREQ_PM     => { 'File::Spec' => 0.82, 'Test::More' => 0},
#    EXE_FILES     => [qw( synctree.pl patchtree.pl mailrpt.pl W32Configure.pl
#                          mktest.pl mkovz.pl smoke.sh smokew32.bat
#                          configsmoke.pl smokeperl.pl
#                          smoke.cfg perl56x.cfg perlcurrent.cfg w32current.cfg
#                          smoke56x_dfconfig smoke58x_dfconfig
#                     )],
    SKIP          => [qw( install )],
);

warn <<EO_MSG

You can now run
\t$Config{make} test
and after success
\t$Config{make} distclean

EO_MSG
