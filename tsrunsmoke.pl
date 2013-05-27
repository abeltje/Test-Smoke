#! /usr/bin/perl -w
use strict;

use lib 'lib';

use Test::Smoke::App::Options;
use Test::Smoke::App::RunSmoke;

my $smoker = Test::Smoke::App::RunSmoke->new(
    Test::Smoke::App::Options->runsmoke_config()
);

if (my $error = $smoker->configfile_error) {
    die "$error\n";
}
$smoker->run();
