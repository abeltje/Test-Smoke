#! perl -w
use strict;
$| = 1;

# $Id$

my $findbin;
use File::Basename;
BEGIN { $findbin = dirname $0; }
use lib $findbin;
use TestLib;

use File::Spec::Functions;
use Test::More;

my @logs;
BEGIN {
    @logs = ( 
        { file => 'w32bcc32.log', type => 'bcc32',   wcnt => 12, ecnt => 1 },
        { file => 'solaris.log',  type => 'solaris', wcnt =>  2, ecnt => 0 },
        { file => 'hpux1020.log', type => 'hpux',    wcnt =>  1, ecnt => 0 },
        { file => 'hpux1111.log', type => 'hpux',    wcnt =>  2, ecnt => 0 },
    );

    plan tests => 1 + 3 * @logs + 1;

    use_ok 'Test::Smoke::Util', 'grepccmsg';
}

my $verbose = $ENV{SMOKE_VERBOSE} || 0;

for my $log ( @logs ) {
    my $file = catfile "t", "logs", $log->{file};
    my @errors = grepccmsg( $log->{type}, $file, $verbose );

    ok @errors, "Found messages in '$log->{file}'";

    my $wcnt = grep /\bwarning\b/i => @errors;
    is $wcnt, $log->{wcnt},
       "Number of warnings: $log->{wcnt}";

    my $ecnt = grep /\berror\b/i => @errors;
    is $ecnt, $log->{ecnt},
       "Number of errors: $log->{ecnt}";
}

{
    my $log = catfile 't', 'logs', 'gcc2722.log';
    my @errors = grepccmsg( 'gcc', $log, $verbose );
    my $report = join "\n", @errors;

    ( my $orig = get_file( $log ) ) =~ s/\n$//;
    is $report, $orig, "Got all the gcc-2.7.2.2 messages";
}
