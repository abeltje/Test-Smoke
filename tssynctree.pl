#! /usr/bin/perl -w
use strict;

use Test::Smoke::App::Options;
use Test::Smoke::App::Syncer;

my $syncer = Test::Smoke::App::Syncer->new(
    Test::Smoke::App::Options->syncer_config()
);

if (my $error = $syncer->configfile_error) {
    die "$error\n";
}
$syncer->run();
