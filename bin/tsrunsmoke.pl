#! /usr/bin/perl -w
use strict;
select(STDERR);
$|++;
select(STDOUT);
$|++;

use File::Spec::Functions;
use FindBin;
use lib $FindBin::Bin;
use lib catdir($FindBin::Bin, 'lib');
use lib catdir($FindBin::Bin, updir(), 'lib');

use Test::Smoke::App::Options;
use Test::Smoke::App::RunSmoke;

my $app = Test::Smoke::App::RunSmoke->new(
    Test::Smoke::App::Options->runsmoke_config()
);

if (my $error = $app->configfile_error) {
    die "$error\n";
}
$app->run();
