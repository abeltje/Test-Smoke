#! perl -w
use strict;
$|++;

use fallback 'inc';

use Test::More;
use Test::NoWarnings ();

use CGI::Util qw/unescape/;
use Config;
use Errno qw/EINTR/;
use JSON;
use Test::Smoke::Poster;
use Test::Smoke::Util qw/whereis/;
use Test::Smoke::Util::FindHelpers 'has_module';

if (!has_module('HTTP::Daemon')) {
    plan skip_all => "Need 'HTTP::Daemon' for this test!";
}
require HTTP::Daemon;
require HTTP::Status; HTTP::Status->import('RC_OK');
require HTTP::Response;
require HTTP::Headers;

my $debug = $ENV{TSDEBUG};

my ($pid, $daemon, $url);

my $timeout = 60;
my $jsnfile = 'testsuite.jsn';
{
    $daemon = HTTP::Daemon->new() || die "Could not initialize a Daemon";
    $url = $daemon->url;

    $pid = fork();
    if ($pid) { # Continue
        note("$url");
    }
    else { # HTTP-Server for dummies
        my $CRLF = "\015\012";
        while (my $c = $daemon->accept) {
            while (my $r = $c->get_request) {
                if ($r->method eq 'POST' && $r->uri->path eq '/report') {
                    (my $json = unescape($r->decoded_content)) =~ s/^json=//;
                    my $data;
                    $data  =  2 if $r->header('User-Agent') =~ /Test::Smoke/;
                    $data += 40 if decode_json($json)->{sysinfo} eq $^O;
                    my $response = HTTP::Response->new(
                        RC_OK(), "OK",
                        HTTP::Headers->new('Content-Type', 'application/json'),
                        encode_json({id => $data}),
                    );
                    $c->send_response($response);
                }
                else {
                    diag("<<<Error: @{[$r->as_string]}>>>");
                }
                $c->close;
            }
        }
    }
}
END {
    unlink "t/$jsnfile";
    if ($pid) {
        note("tear down: $pid");
        $daemon->close;
        kill 9, $pid;
    }
}

SKIP: {
    skip("Could not load LWP::UserAgent", 3) if !has_module('LWP::UserAgent');

    my $poster = Test::Smoke::Poster->new(
        'LWP::UserAgent',
        ddir        => 't',
        jsnfile     => 'testsuite.jsn',
        smokedb_url => "${url}report",
        v           => $debug ? 2 : 0,
    );
    isa_ok($poster, 'Test::Smoke::Poster::LWP_UserAgent');

    ok(write_json($poster->json_filename, {sysinfo => $^O}), "write_json");
    is($poster->post(), 42, "Got id");

    unlink $poster->json_filename;
}

SKIP: {
    my $curlbin = whereis('curl');
    skip("Could find curl", 3) if !$curlbin;

    my $poster = Test::Smoke::Poster->new(
        'curl',
        ddir        => 't',
        jsnfile     => 'testsuite.jsn',
        smokedb_url => "${url}report",
        curlbin     => $curlbin,
        v           => $debug ? 2 : 0,
    );
    isa_ok($poster, 'Test::Smoke::Poster::Curl');

    ok(write_json($poster->json_filename, {sysinfo => $^O}), "write_json");
    is($poster->post(), 42, "Got id");

    unlink $poster->json_filename;
}

SKIP: {
    skip("Could not load HTTP::Tiny", 3) if ! has_module('HTTP::Tiny');

    my $poster = Test::Smoke::Poster->new(
        'HTTP::Tiny',
        ddir        => 't',
        jsnfile     => 'testsuite.jsn',
        smokedb_url => "${url}report",
        v           => $debug ? 2 : 0,
    );
    isa_ok($poster, 'Test::Smoke::Poster::HTTP_Tiny');

    ok(write_json($poster->json_filename, {sysinfo => $^O}), "write_json");
    is($poster->post(), 42, "Got id");

    unlink $poster->json_filename;
}

SKIP: {
    skip("Could not load HTTP::Lite", 3) if ! has_module('HTTP::Lite');

    my $poster = Test::Smoke::Poster->new(
        'HTTP::Lite',
        ddir        => 't',
        jsnfile     => 'testsuite.jsn',
        smokedb_url => "${url}report",
        v           => $debug ? 2 : 0,
    );
    isa_ok($poster, 'Test::Smoke::Poster::HTTP_Lite');

    ok(write_json($poster->json_filename, {sysinfo => $^O}), "write_json");
    is($poster->post(), 42, "Got id");

    unlink $poster->json_filename;
}

Test::NoWarnings::had_no_warnings();
$Test::NoWarnings::do_end_test = 0;
done_testing();

sub write_json {
    my ($file, $content) = @_;

    open my $fh, '>', $file or die "Cannot create($file): $!";
    print $fh encode_json($content);
    close $fh;
    return 1;
}
