#! perl -w
use strict;

use Test::More 'no_plan';

use Test::Smoke::App::SyncTree;

{
    my $app = Test::Smoke::App::SyncTree->new(
    );
    isa_ok($app, 'Test::Smoke::App::SyncTree');
}

# done_testing();

