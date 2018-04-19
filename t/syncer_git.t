#! perl -w
use strict;

use lib 't';
use TestLib;
use Test::More;

use Test::Smoke::Syncer;
use Test::Smoke::Util::Execute;
use File::Spec::Functions;
use Cwd 'abs_path';
use File::Temp 'tempdir';

my $gitbin = whereis('git');
plan $gitbin ? ('no_plan') : (skip_all => 'No gitbin found');

my $git = Test::Smoke::Util::Execute->new(command => $gitbin);
(my $gitversion = $git->run('--version')) =~ s/\s*\z//;
$gitversion =~ s/^\s*git\s+version\s+//;
pass("Git version $gitversion");

my $cwd = abs_path();
my $tmpdir = tempdir(CLEANUP => ($ENV{SMOKE_DEBUG} ? 0 : 1));
my $upstream = catdir($tmpdir, 'tsgit');
my $playground = catdir($tmpdir, 'playground');

if ($gitversion =~ m/^1\.([0-5]|6\.[0-4])/) {
    diag "Git version $gitversion is too old";
}
else {
    # Set up a basic git repository
    $git->run(init => $upstream);
    is($git->exitcode, 0, "git init $upstream");

    mkpath("$upstream/Porting");
    chdir $upstream;
    put_file($gitversion => 'first.file');
    $git->run(add => q/first.file/);

    put_file(<<"    CAT" => qw/Porting make_dot_patch.pl/);
#! $^X -w
(\@ARGV,\$/)=q/first.file/;
print <>;
    CAT
    $git->run(add => 'Porting/make_dot_patch.pl');

    put_file(".patch" => q/.gitignore/);
    $git->run(add => '.gitignore');

    $git->run(commit => '-m', "'We need a first file committed'", '2>&1');

    chdir catdir(updir, updir);
    mkpath($playground);
    {
        my $syncer = Test::Smoke::Syncer->new(
            git => (
                gitbin      => $gitbin,
                gitorigin   => $upstream,
                gitdfbranch => 'master',
                gitdir      => catdir($playground, 'git-perl'),
                ddir        => catdir($playground, 'perl-current'),
                v           => 0, #($ENV{TEST_VERBOSE} ? 1 : 0),
            ),
        );
        isa_ok($syncer, 'Test::Smoke::Syncer::Git');
        is(
            $syncer->{gitdfbranch},
            'master',
            "  Right defaultbranch: $syncer->{gitdfbranch}"
        );

        $syncer->sync();
        ok(!-e catfile(catdir($playground, 'git-perl'), '.patch'), "  no .patch for gitdir");
        ok(-e catfile(catdir($playground, 'perl-current'), '.patch'), "  .patch created");

        # Update upstream/master
        chdir $upstream;
        put_file('any content' => q/new_file/);
        $git->run(add => 'new_file', '2>&1');
        $git->run(commit => '-m', "'2nd commit message'", '2>&1');
        chdir catdir(updir, updir);

        $syncer->sync();
        ok(-e catfile(catdir($playground, 'git-perl'), 'new_file'), "new_file exits after sync()");
        ok(-e catfile(catdir($playground, 'perl-current'), 'new_file'), "new_file exits after sync()");

        # Create upstream/branch
        chdir $upstream;
        $git->run(checkout => '-b', 'branch', '2>&1');
        put_file('new file in branch' => 'branch_file');
        $git->run(add => 'branch_file', '2>&1');
        $git->run(commit => '-m', "File in branch!", '2>&1');
        chdir catdir(updir, updir);

        # Sync master.
        $syncer->sync();
        ok(
            !-e catfile(catdir($playground, 'perl-current'), 'branch_file'),
            "branch_file doesn't exit after sync()!"
        );

        # Change to 'branch' and sync
        $syncer->{gitdfbranch} = 'branch';
        $syncer->sync();
        ok(
            -e catfile(catdir($playground, 'perl-current'), 'branch_file'),
            "branch_file does exit after sync()!"
        );
    }
}

END {
    chdir $cwd;
    note("$playground: ", rmtree($playground, 1, 0));
    note("$upstream: ", rmtree($upstream, 1, 0));
}
