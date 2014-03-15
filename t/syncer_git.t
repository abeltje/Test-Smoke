#! perl -w
use strict;

use lib 't';
use TestLib;
use Test::More;

use Test::Smoke::Syncer;
use Test::Smoke::Util::Execute;

my $gitbin = whereis('git');
plan $gitbin ? ('no_plan') : (skip_all => 'No gitbin found');

my $git = Test::Smoke::Util::Execute->new(command => $gitbin);
(my $gitversion = $git->run('--version')) =~ s/\s*\z//;
pass("Git version $gitversion");

# Set up a basic git repository
my $repopath = 't/tsgit';
$git->run(init => $repopath);
is($git->exitcode, 0, "git init $repopath");

mkpath("$repopath/Porting");
chdir $repopath;
put_file($gitversion => 'first.file');
$git->run(add => 'first.file');
put_file("#! $^X -w\nsystem q/cat first.file/" => qw/Porting make_dot_patch.pl/);
$git->run(add => 'Porting/make_dot_patch.pl');
$git->run(commit => '-m', "'We need a first file committed'");

chdir '../..';
mkpath('t/smokeme');
{
    my $syncer = Test::Smoke::Syncer->new(
        git => (
            gitbin      => $gitbin,
            gitorigin   => 't/tsgit',
            gitdfbranch => 'master',
            gitdir      => 't/smokeme/git-perl',
            ddir        => 't/smokeme/perl-current',
            v           => 0,
        ),
    );
    isa_ok($syncer, 'Test::Smoke::Syncer::Git');
    is(
        $syncer->{gitdfbranch},
        'master',
        "  Right defaultbranch: $syncer->{gitdfbranch}"
    );

    $syncer->sync();
    ok(!-e 't/smokeme/git-perl/.patch', "  no .patch for gitdir");
    ok(-e 't/smokeme/perl-current/.patch', "  .patch created");
}

END {
    rmtree('t/smokeme', 0, 0);
    rmtree('t/tsgit', 0, 0);
}
