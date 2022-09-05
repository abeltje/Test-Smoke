#! /usr/bin/env -S perl -w
use strict;
$|++;

my %ts_matrix = (
    'tsarcheve.pl' => {
        class  => 'Test::Smoke::App::Archiver',
        config => 'archiver_config',
    },
    'tsreport.pl' => {
        class  => 'Test::Smoke::App::Reporter',
        config => 'reporter_config',
    },
    'tsrepostjsn.pl' => {
        class  => 'Test::Smoke::App::RepostFromArchive',
        config => 'reposter_config',
    },
    'tsrunsmoke.pl' => {
        class  => 'Test::Smoke::App::RunSmoke',
        config => 'runsmoke_config',
    },
    'tssendrpc.pl' => {
        class  => 'Test::Smoke::App::SendReport',
        config => 'sendreport_config',
    },
    'tssmokeperl.pl' => {
        class  => 'Test::Smoke::App::SmokePerl',
        config => 'smokeperl_config',
    },
    'tssynctree.pl' => {
        class  => 'Test::Smoke::App::SyncTree',
        config => 'synctree_config',
    },
);
use File::Basename;

use File::Spec::Functions;
use FindBin;
use lib $FindBin::Bin;
use lib catdir($FindBin::Bin, 'lib');
use lib catdir($FindBin::Bin, updir(), 'lib');

use Test::Smoke::App::Options;

my $basename = basename($0);
if (! exists $ts_matrix{$basename}) {
    die <<EOM;
'$basename' is not a known Test::Smoke tool!
EOM
}

my $class  = $ts_matrix{$basename}{class};
my $config = $ts_matrix{$basename}{config};

eval "use $class;";
die $@ if $@;

my $app = $class->new(
    Test::Smoke::App::Options->$config
);

if (my $error = $app->configfile_error) {
    die "$error\n";
}

$app->run();
