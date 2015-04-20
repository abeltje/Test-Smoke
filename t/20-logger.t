#! perl -w
use strict;

BEGIN {
    *CORE::GLOBAL::localtime = sub { CORE::localtime(@_) };
}

use Test::More;
use Test::NoWarnings ();

# Make sure the tests use the same TZ!
use POSIX 'tzset';
$ENV{TZ} = 'UTC'; tzset();

{
    no warnings 'redefine';
    local *CORE::GLOBAL::localtime = sub {
        return (2, 11, 14, 15, 3, 115, 3, 104, 1);
    };
    my $t0 = LogTest->new(v => 0);
    isa_ok($t0, 'LogTest');
    open my $fh0, '>', \my $o0;
    {
        my $stdout = select $fh0; $|++;
        $t0->log_warn_test();
        $t0->log_info_test();
        $t0->log_debug_test();
        select $stdout;
    }
    is($o0, <<'    EOL', "v==0 => log_warn");
[2015-04-15 14:11:02+0000] ->log_warn()
    EOL

    my $t1 = LogTest->new(v => 1);
    isa_ok($t1, 'LogTest');
    open my $fh1, '>', \my $o1;
    {
        my $stdout = select $fh1; $|++;
        $t1->log_warn_test();
        $t1->log_info_test();
        $t1->log_debug_test();
        select $stdout;
    }
    is($o1, <<'    EOL', "v==1 => log_warn, log_info");
[2015-04-15 14:11:02+0000] ->log_warn()
[2015-04-15 14:11:02+0000] ->log_info()
    EOL

    my $t2 = LogTest->new(v => 2);
    isa_ok($t2, 'LogTest');
    open my $fh2, '>', \my $o2;
    {
        my $stdout = select $fh2; $|++;
        $t2->log_warn_test();
        $t2->log_info_test();
        $t2->log_debug_test();
        select $stdout;
    }
    is($o2, <<'    EOL', "v==2 => log_warn, log_info, log_debug");
[2015-04-15 14:11:02+0000] ->log_warn()
[2015-04-15 14:11:02+0000] ->log_info()
[2015-04-15 14:11:02+0000] ->log_debug()
    EOL

    my $t4 = LogTest->new(verbose => 1);
    isa_ok($t4, 'LogTest');
    open my $fh4, '>', \my $o4;
    {
        my $stdout = select $fh4; $|++;
        $t4->log_warn_test();
        $t4->log_info_test();
        $t4->log_debug_test();
        select $stdout;
    }
    is($o4, <<'    EOL', "verbose==1 => log_warn, log_info");
[2015-04-15 14:11:02+0000] ->log_warn()
[2015-04-15 14:11:02+0000] ->log_info()
    EOL

}

{
    no warnings 'redefine';
    local *CORE::GLOBAL::localtime = sub {
        return (2, 11, 14, 15, 3, 115, 3, 104, 1);
    };
    my $logger = Test::Smoke::Logger->new(v => 0);
    isa_ok($logger, 'Test::Smoke::Logger');
    open my $lh, '>', \my $logfile;
    my $stdout = select $lh;
    $logger->log_warn("do_log_warn()");
    $logger->log_info("do_log_info()");
    $logger->log_debug("do_log_debug()");
    select $stdout;
    is($logfile, <<'    EOL', "logfile (v=0)");
[2015-04-15 14:11:02+0000] do_log_warn()
    EOL
}

{ # Test the $Test::Smoke::LogMixin::USE_TIMESTAMP switch.
    local $Test::Smoke::LogMixin::USE_TIMESTAMP = 0;
    no warnings 'redefine';
    local *CORE::GLOBAL::localtime = sub {
        return (2, 11, 14, 15, 3, 115, 3, 104, 1);
    };
    my $logger = Test::Smoke::Logger->new(v => 2);
    isa_ok($logger, 'Test::Smoke::Logger');
    open my $lh, '>', \my $logfile;
    my $stdout = select $lh;
    $logger->log_warn("do_log_warn()");
    $logger->log_info("do_log_info()");
    $logger->log_debug("do_log_debug()");
    select $stdout;
    is($logfile, <<'    EOL', "logfile (v=2); no timestamp");
do_log_warn()
do_log_info()
do_log_debug()
    EOL
}

Test::NoWarnings::had_no_warnings();
$Test::NoWarnings::do_end_test = 0;
done_testing();

package LogTest;
use base 'Test::Smoke::ObjectBase';
use Test::Smoke::LogMixin;

sub new {
    my $class = shift;
    my %raw = @_;
    my $fields;
    for my $fld (keys %raw) { $fields->{"_$fld"} = $raw{$fld} }
    return bless $fields, $class;
}

sub log_warn_test {
    my $self = shift;
    $self->log_warn("->log_warn()");
}

sub log_info_test {
    my $self = shift;
    $self->log_info("->log_info()");
}

sub log_debug_test {
    my $self = shift;
    $self->log_debug("->log_debug()");
}

1;
