#! /usr/perl/perl -w
use strict;

use FindBin;
use Data::Dumper;

use Test::More tests => 6;

BEGIN { use_ok( 'Test::Smoke' ) }

is( Test::Smoke->VERSION, $Test::Smoke::VERSION, 
    "Check version $Test::Smoke::VERSION" );
ok( defined &read_config, "read_config() is exported" );

my $test = { ddir => '../' };

SKIP: {
    my $config_name = File::Spec->catfile( $FindBin::Bin, 
                                           'smokecurrent_config' );
    local *FILE;
    open FILE, "> $config_name" or skip "Cannot write file: $!", 2;
    print FILE Data::Dumper->Dump( [$test], ['conf'] );
    close FILE or skip "Cannot close file: $!", 2;

    ok( read_config( $config_name ), "read_config($config_name)" );
    is( Test::Smoke->config_error, undef, "No errors" );
    is_deeply( $conf, $test, "Configuration compares" );

    1 while unlink $config_name;
}

    
