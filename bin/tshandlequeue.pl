#! /usr/bin/perl -w
use strict;
$|++;

use File::Spec::Functions;
use FindBin;
use lib $FindBin::Bin;
use lib catdir($FindBin::Bin, 'lib');
use lib catdir($FindBin::Bin, updir(), 'lib');

use Test::Smoke::App::HandleQueue;
use Test::Smoke::App::Options;

my $app = Test::Smoke::App::HandleQueue->new(
    Test::Smoke::App::Options->handlequeue_config()
);

if (my $error = $app->configfile_error) {
    die "$error\n";
}

$app->run();
