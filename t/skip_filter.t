#! perl -w
use strict;

use File::Spec;

use Test::More tests => 14;

BEGIN { use_ok( 'Test::Smoke::Util' ); }

while ( <DATA> ) {
    my( $pf, $line ) = /^(.) (.*)$/;

    if ( $pf =~ /[pP]/ ) {
        ok( skip_filter( $line ), "P: $line" );
    } else {
        ok( !skip_filter( $line ), "F: $line" );
    }
}

# Add the test-lines after __DATA__ 
# First char should be 'P' for PASS (we don't want it)
# and 'F' for FAIL (we _do_ want it)
# Second char should be a single space (for readability)
# Rest of the line will be tested!

__DATA__
P op/strict.............ok
F op/strict.............FAILED
F       FAILED 4/10
P t/op/64bitint........................skipping test on this platform
F run/switches...........................FAILED test 7
F        Failed 1/20 tests, 95.00% okay
F Failed 1/736 test scripts, 99.86% okay. 1/70360 subtests failed, 100.00% okay.
F Failed Test    Stat Wstat Total Fail  Failed  List of Failed
F -------------------------------------------------------------------------------
F run/switches.t               20    1   5.00%  7
F 54 tests and 609 subtests skipped.
P C:\usr\local\src\bleadperl\perl\miniperl.exe "-I..\..\lib" "-I..\..\lib" -MExtUtils::Command -e cp bin/piconv blib\script\piconv
P C:\usr\local\src\bleadperl\perl\miniperl.exe "-I..\..\lib" "-I..\..\lib" -MExtUtils::Command -e cp bin/enc2xs blib\script\enc2xs
