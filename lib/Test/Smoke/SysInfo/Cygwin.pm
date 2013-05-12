package Test::Smoke::SysInfo::Cygwin;
use warnings;
use strict;

use base 'Test::Smoke::SysInfo::Linux';

use POSIX ();

sub prepare_sysinfo {
    my $self = shift;
    $self->SUPER::prepare_sysinfo();

    return $self;
}

sub prepare_os {
    my $self = shift;

    my @uname = POSIX::uname();

    $self->{__osname} = $uname[0];
    $self->{__osvers} = $uname[2];
    my $os = join " - ", @uname[0,2];
    $os =~ s/(\S+)/\L$1/;
    $self->{__os} = $os;
}

1;
