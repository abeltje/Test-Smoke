#! perl -w
use strict;

use Test::More 'no_plan';

use Test::Smoke::App::SyncTree;
use Test::Smoke::App::Options;
my $opt = 'Test::Smoke::App::Options';

{
    # local @ARGV = ('--show-config');
    my $app = Test::Smoke::App::SyncTree->new(
        main_options    => [$opt->syncer(), $opt->poster()],
        special_options => {
            'git' => [
                $opt->gitbin(),
                $opt->gitdir(),
            ],
        },
    );
    isa_ok($app, 'Test::Smoke::App::SyncTree');
}

# done_testing();

