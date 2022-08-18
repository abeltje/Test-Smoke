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
plan skip_all => 'No gitbin found' if !$gitbin;

my $verbose = $ENV{SMOKE_DEBUG} ? 3 : $ENV{TEST_VERBOSE} ? $ENV{TEST_VERBOSE} : 0;
my $git = Test::Smoke::Util::Execute->new(command => $gitbin, verbose => $verbose);
(my $gitversion = $git->run('--version')) =~ s/\s*\z//;
$gitversion =~ s/^\s*git\s+version\s+//;

plan skip_all => "Git version '$gitversion' is too old"
    if ($gitversion =~ m/^1\.([0-5]|6\.[0-4])/);

my $cwd = abs_path();
my $tmpdir = tempdir(CLEANUP => ($ENV{SMOKE_DEBUG} ? 0 : 1));
my $upstream = catdir($tmpdir, 'tsgit');
my $playground = catdir($tmpdir, 'playground');
my $branchfile = catfile($tmpdir, 'default.gitbranch');
my $branchname = 'main'; # instead of "master" to prevent warnings

SKIP: {
    pass("Git version $gitversion");
    # Set up a basic git repository
    $git->run(init => '-b', $branchname, $upstream);
    unless (is($git->exitcode, 0, "git init $upstream")) {
        skip "git init failed! The tests require an empty/different repo";
    }

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
    put_file("$branchname\n" => $branchfile);
    mkpath($playground);
    {
        my $syncer = Test::Smoke::Syncer->new(
            git => (
                gitbin        => $gitbin,
                gitorigin     => $upstream,
                gitdfbranch   => 'blead',
                gitbranchfile => $branchfile,
                gitdir        => catdir($playground, 'git-perl'),
                ddir          => catdir($playground, 'perl-current'),
                v             => $verbose,
            ),
        );
        isa_ok($syncer, 'Test::Smoke::Syncer::Git');
        is(
            $syncer->{gitdfbranch},
            'blead',
            "  Right defaultbranch: $syncer->{gitdfbranch}"
        );
        is(
            $syncer->get_git_branch,
            $branchname,
            "  from branchfile: chomp()ed value"
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

        # Create upstream/smoke-me
        chdir $upstream;
        $git->run(checkout => '-b', 'smoke-me', '2>&1');
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

        # update a file in perl-current without commiting
        # this happens to patchlevel.h during smoke
        put_file('new content' => ($playground, qw/perl-current first.file/));

        # Change to 'branch' and sync
        put_file('smoke-me' => $branchfile);
        $syncer->sync();
        ok(
            -e catfile(catdir($playground, 'perl-current'), 'branch_file'),
            "branch_file does exit after sync()!"
        );
        {
            chdir(catdir($playground, 'perl-current'));
            my $git_out = $git->run('branch');
            like($git_out, qr/\* \s+ smoke-me/x, "We're on the smoke-me branch");
            chdir(catdir(updir, updir));
        }
    }
}

done_testing();

END {
    chdir $cwd;
    note("$playground: ", rmtree($playground, $ENV{SMOKE_DEBUG}, 0));
    note("$upstream: ", rmtree($upstream, $ENV{SMOKE_DEBUG}, 0));
}
