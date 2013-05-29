#! perl -w
use strict;

use Test::More 'no_plan';

use Test::Smoke::App::SendReport;

{
    my $app = Test::Smoke::App::SendReport->new(
    );
    isa_ok($app, 'Test::Smoke::App::SendReport');
}

# done_testing();

