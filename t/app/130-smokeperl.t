#! perl -w
use strict;

use Test::More 'no_plan';

use Test::Smoke::App::SmokePerl;
use Test::Smoke::App::Options;
my $opt = 'Test::Smoke::App::Options';

{
    local @ARGV = ('--ddir', 't/perl', '--poster', 'curl', '--curlbin', 'curl');
    my $app = Test::Smoke::App::SmokePerl->new(
        main_options    => [$opt->syncer(), $opt->poster()],
        general_options => [$opt->ddir()],
        special_options => {
            'git' => [
                $opt->gitbin(),
                $opt->gitdir(),
            ],
            'curl' => [ $opt->curlbin() ],
        },
    );
    isa_ok($app, 'Test::Smoke::App::SmokePerl');
}

# done_testing();

