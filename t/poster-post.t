#! perl -w
use strict;

use fallback 'inc';

use Test::More;
use Test::NoWarnings ();

use CGI::Util qw/unescape/;
use Config;
use Errno qw/EINTR/;
use JSON;
use Test::Smoke::Poster;
use Test::Smoke::Util qw/whereis/;

my $debug = $ENV{TSDEBUG};

my ($pid, $port, $socket);
my $timeout = 60;
my $jsnfile = 'testsuite.jsn';
{
    use IO::Socket::INET;
    $socket = IO::Socket::INET->new(
        Listen   => 1024,
        Proto    => 'tcp',
        Blocking => 1,
    );
    $port = $socket->sockport;
    $pid = fork();
    if ($pid) { # Continue
        plan(tests => 9);
        note("http://localhost:$port started (killed in $timeout s)");
    }
    else { # HTTP-Server for dummies
        my $CRLF = "\015\012";
        while (my $httpd = $socket->accept()) {
            vec(my $fdset = "", $httpd->fileno, 1) = 1;
            my ($cnt, $buffer, $blck, $to) = (0, "", 1024, 0);
            #$to = select($fdset, undef, undef, $timeout);
            do {
                $cnt = sysread( $httpd, $buffer, $blck, length($buffer) );
                ::diag("[Read buffer] ($cnt/$blck): $buffer") if $debug;
            } until $cnt < $blck;
            my @message = split(/\015?\012/, $buffer);
            $cnt = length($buffer);
            ::diag("[message] ($cnt)", ::explain(\@message)) if $debug;

            my $data;
            $data  = 2 if grep /^User-Agent:/ && /Test::Smoke/, @message;
            my ($json) = map {s/^json=//; $_} grep /^json=/, @message;
            $json = decode_json(unescape($json) || '{"sysinfo":""}');
            $data += 40 if $json->{sysinfo} eq $^O;

            my $to_send = encode_json({id => $data});
            my $send_cnt = length($to_send . $CRLF);

            ::diag("[response] ($send_cnt) $to_send") if $debug;
            print $httpd "HTTP/1.0 200 OK$CRLF";
            print $httpd "Content-Type: application/json$CRLF";
            print $httpd "Content-Length: $send_cnt$CRLF";
            print $httpd "$CRLF";
            print $httpd "$to_send$CRLF";
            close $httpd;
        }
    }
}
END {
    unlink "t/$jsnfile";
    if ($pid) {
        note("tear down: $pid");
        $socket->close;
        kill 9, $pid;
    }
}

SKIP: {
    eval { local $^W; require LWP::UserAgent };
    skip("Could not load LWP::UserAgent", 2) if $@;

    my $poster = Test::Smoke::Poster->new(
        'LWP::UserAgent',
        ddir        => 't',
        jsnfile     => 'testsuite.jsn',
        smokedb_url => "http://localhost:$port/report",
    );
    isa_ok($poster, 'Test::Smoke::Poster::LWP_UserAgent');

    write_json($poster->json_filename, {sysinfo => $^O});
    is($poster->post(), 42, "Got id");

    unlink $poster->json_filename;
}

SKIP: {
    my $curlbin = whereis('curl');
    skip("Could find curl", 2) if !$curlbin;

    my $poster = Test::Smoke::Poster->new(
        'curl',
        ddir        => 't',
        jsnfile     => 'testsuite.jsn',
        smokedb_url => "http://localhost:$port/report",
        curlbin     => $curlbin,
        v           => 0,
    );
    isa_ok($poster, 'Test::Smoke::Poster::Curl');

    write_json($poster->json_filename, {sysinfo => $^O});
    is($poster->post(), 42, "Got id");

    unlink $poster->json_filename;
}

SKIP: {
    eval { local $^W; require HTTP::Tiny; die "Not available atm.\n" };
    skip("Could not load HTTP::Tiny", 2) if $@;

    my $poster = Test::Smoke::Poster->new(
        'HTTP::Tiny',
        ddir        => 't',
        jsnfile     => 'testsuite.jsn',
        smokedb_url => "http://localhost:$port/report",
    );
    isa_ok($poster, 'Test::Smoke::Poster::HTTP_Tiny');

    local $TODO = "Fix local daemon";
    write_json($poster->json_filename, {sysinfo => $^O});
    is($poster->post(), 42, "Got id");

    unlink $poster->json_filename;
}

SKIP: {
    eval { local $^W; require HTTP::Lite; die "Not available atm.\n" };
    skip("Could not load HTTP::Lite", 2) if $@;

    my $poster = Test::Smoke::Poster->new(
        'HTTP::Lite',
        ddir        => 't',
        jsnfile     => 'testsuite.jsn',
        smokedb_url => "http://localhost:$port/report",
    );
    isa_ok($poster, 'Test::Smoke::Poster::HTTP_Lite');

    local $TODO = "Fix local daemon";
    write_json($poster->json_filename, {sysinfo => $^O});
    is($poster->post(), 42, "Got id");

    unlink $poster->json_filename;
}

Test::NoWarnings::had_no_warnings();
# done_testing();

sub write_json {
    my ($file, $content) = @_;

    open my $fh, '>', $file or die "Cannot create($file): $!";
    print $fh encode_json($content);
    close $fh;
}
