#! perl -w
use strict;

use Test::More 'no_plan';

use Test::Smoke::App::Archiver;

{
    my $app = Test::Smoke::App::Archiver->new(
    );
    isa_ok($app, 'Test::Smoke::App::Archiver');
}

# done_testing();
