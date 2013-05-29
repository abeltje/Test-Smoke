#! perl -w
use strict;

use Test::More 'no_plan';

use Test::Smoke::App::SmokePerl;

{
    my $app = Test::Smoke::App::SmokePerl->new(
    );
    isa_ok($app, 'Test::Smoke::App::SmokePerl');
}

# done_testing();

