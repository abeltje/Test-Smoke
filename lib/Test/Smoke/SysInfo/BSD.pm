package Test::Smoke::SysInfo::BSD;
use warnings;
use strict;

use base 'Test::Smoke::SysInfo::Base';

sub prepare_sysinfo {
    my $self = shift;
    $self->SUPER::prepare_sysinfo();

    my $sysctl = __get_sysctl();

    my $cpu = $sysctl->{model};

    if ( exists $sysctl->{cpuspeed} ) {
        $cpu .= sprintf " (%.0f MHz)", $sysctl->{cpuspeed};
    }
    elsif ( exists $sysctl->{cpufrequency} ) {
        $cpu .= sprintf " (%.0f MHz)", $sysctl->{cpufrequency}/1_000_000;
    }

    $self->{__cpu_type} = $sysctl->{machine} if $sysctl->{machine};
    $self->{__cpu} = $cpu if $cpu;
    $self->{__cpu_count} = $sysctl->{ncpu};

    return $self;
}

sub __get_sysctl {
    my %sysctl;

    my $sysctl_cmd = -x '/sbin/sysctl' ? '/sbin/sysctl' : 'sysctl';

    my %extra = ( cpufrequency => undef, cpuspeed => undef );
    my @e_args = map {
        /^hw\.(\w+)\s*[:=]/; $1
    } grep /^hw\.(\w+)/ && exists $extra{ $1 } => `$sysctl_cmd -a hw`; 

    foreach my $name ( qw( model machine ncpu ), @e_args ) {
        chomp( $sysctl{ $name } = `$sysctl_cmd hw.$name` );
        $sysctl{ $name } =~ s/^hw\.$name\s*[:=]\s*//;
    }
    $sysctl{machine} and $sysctl{machine} =~ s/Power Macintosh/macppc/;

    return \%sysctl;
}

1;
