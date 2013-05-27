#! /usr/bin/perl -w
use strict;

use lib 'lib';

use Test::Smoke::App::Options;
use Test::Smoke::App::SendReport;

my $sendrpt = Test::Smoke::App::SendReport->new(
    Test::Smoke::App::Options->sendreport_config()
);

if (my $error = $sendrpt->configfile_error) {
    die "$error\n";
}
$sendrpt->run();

