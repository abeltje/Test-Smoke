#! perl -w
use strict;

use Test::More 'no_plan';

use Test::Smoke::App::RunSmoke;

{
    my $app = Test::Smoke::App::RunSmoke->new(
    );
    isa_ok($app, 'Test::Smoke::App::RunSmoke');
}

# done_testing();
