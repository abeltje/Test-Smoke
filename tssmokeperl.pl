#! /usr/bin/perl -w
use strict;

use lib 'lib';

use Test::Smoke::App::Options;
use Test::Smoke::App::SmokePerl;

my $app = Test::Smoke::App::SmokePerl->new(
    Test::Smoke::App::Options->smokeperl_config()
);

if (my $error = $app->configfile_erro) {
    die "$error\n";
}

$app->run();
