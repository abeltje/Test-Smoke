package Test::Smoke::SysInfo::VMS;
use warnings;
use strict;

use base 'Test::Smoke::SysInfo::Base';

use POSIX ();

sub prepare_sysinfo {
    my $self = shift;
    $self->SUPER::prepare_sysinfo();

    my %map = (
        __cpu       => 'HW_NAME',
        __cpu_type  => 'ARCH_NAME',
        __cpu_count => 'ACTIVECPU_CNT'
    );
    for my $key ( keys %map ) {
        chomp( my $cmd_out = `write sys\$output f\$getsyi("$map{$key}")` );
        $self->{$key} = $cmd_out;
    }
    return $self;
}

sub prepare_os {
    my $self = shift;

    my $os = join " - ", ( POSIX::uname() )[ 0, 3 ];
    $os =~ s/(\S+)/\L$1/;
    $self->{__os} = $os;
}

1;
