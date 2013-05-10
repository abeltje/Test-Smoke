package Test::Smoke::SysInfo::Darwin;
use warnings;
use strict;

use base 'Test::Smoke::SysInfo::BSD';

sub prepare_sysinfo {
    my $self = shift;
    $self->Test::Smoke::SysInfo::Base::prepare_sysinfo();

    $self->{__os} .= " (Mac OS X)";
    my $system_profiler = __get_system_profiler();
    return $self->SUPER::prepare_sysinfo() if ! $system_profiler;

    my $model = $system_profiler->{'Machine Name'} ||
                $system_profiler->{'Machine Model'};

    my $ncpu = $system_profiler->{'Number Of CPUs'};
    if ($system_profiler->{'Total Number Of Cores'}) {
        $ncpu .= " [$system_profiler->{'Total Number Of Cores'} cores]";
    }

    $self->{__cpu_type} = $system_profiler->{'CPU Type'}
        if $system_profiler->{'CPU Type'};
    $self->{__cpu} = "$model ($system_profiler->{'CPU Speed'})";
    $self->{__cpu_count} = $ncpu;

    return $self;
}

sub __get_system_profiler {
    my $system_profiler_output;
    {
        local $^W = 0;
        $system_profiler_output =
            `/usr/sbin/system_profiler -detailLevel mini SPHardwareDataType`;
    }
    return if ! $system_profiler_output;

    my %system_profiler;
    $system_profiler{$1} = $2
        while $system_profiler_output =~ m/^\s*([\w ]+):\s+(.+)$/gm;

    # convert newer output from Intel core duo
    my %keymap = (
        'Processor Name'       => 'CPU Type',
        'Processor Speed'      => 'CPU Speed',
        'Model Name'           => 'Machine Name',
        'Model Identifier'     => 'Machine Model',
        'Number Of Processors' => 'Number Of CPUs',
    );
    for my $newkey ( keys %keymap ) {
        my $oldkey = $keymap{$newkey};
        if (exists $system_profiler{$newkey}) {
            $system_profiler{$oldkey} = delete $system_profiler{$newkey};
        }
    }

    $system_profiler{'CPU Type'} =~ s/PowerPC\s*(\w+).*/macppc$1/;
    $system_profiler{'CPU Speed'} =~ 
        s/(0(?:\.\d+)?)\s*GHz/sprintf("%d MHz", $1 * 1000)/e;

    return \%system_profiler;
}

1;
