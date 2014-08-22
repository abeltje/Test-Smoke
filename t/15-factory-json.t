#! perl -w
use strict;

my $lib;
use File::Path;
BEGIN {
    $lib = 't/Factory';
    mkpath("$lib/JSON", $ENV{TEST_VERBOSE});
}
use lib 'inc';
use lib $lib;

use JSON; # Should be our factory type module.

require Scalar::Util;	# Now needed for Test::More (isa_ok)
use Test::More 'no_plan';

my %code = (
    'PP' => <<'    EOPP',
package JSON::PP;
    EOPP
    'XS' => <<'    EOXS',
package JSON::XS;
    EOXS
    General => <<'    EOGEN',
sub new { my $c = shift; return bless {}, $c; }
sub encode_json { return __PACKAGE__ . "\::encode_json()"; }
sub decode_json { return __PACKAGE__ . "\::decode_json()"; }
1;
    EOGEN
);

{
    like($INC{'JSON.pm'}, qr{(?:^|/)inc/}, "Loaded the correct JSON.pm");
}

{
    my $type = 'PP';
    my $fname = "$lib/JSON/$type.pm";
    note("Check we can find JSON::$type");

    # Write the contents of the mock module
    open my $pkg, '>', $fname or die "Cannot create($fname): $!";
    print $pkg $code{$type};
    print $pkg $code{General};
    close $pkg;

    local @INC = ('inc', $lib);
    my $obj = JSON->new;
    isa_ok($obj, 'JSON::PP');

    is(encode_json(), 'JSON::PP::encode_json()', "JSON::PP::encode_json()");
    is(decode_json(), 'JSON::PP::decode_json()', "JSON::PP::decode_json()");
}

{
    my $type = 'XS';
    my $fname = "$lib/JSON/$type.pm";
    note("Check we can find JSON::$type");
    open my $pkg, '>', $fname or die "Cannot create($fname): $!";
    print $pkg $code{$type};
    print $pkg $code{General};
    close $pkg;

    local @INC = ('inc', $lib);
    my $obj = JSON->new;
    isa_ok($obj, 'JSON::XS');

    is(encode_json(), 'JSON::XS::encode_json()', "JSON::XS::encode_json()");
    is(decode_json(), 'JSON::XS::decode_json()', "JSON::XS::decode_json()");
}

rmtree($lib, $ENV{TEST_VERBOSE});
