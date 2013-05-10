package Test::Smoke::SysInfo::Windows;
use warnings;
use strict;

use base 'Test::Smoke::SysInfo::Base';

sub prepare_sysinfo {
    my $self = shift;
    $self->SUPER::prepare_sysinfo();
    $self->prepare_os();

    my $reginfo = __get_registry_sysinfo();
    my $envinfo = __get_environment_sysinfo();

    for my $key (qw/__cpu_type __cpu __cpu_count/) {
        my $value = $reginfo->{$key} || $envinfo->{$key};
        $self->{$key} = $value if $value;
    }
    return $self;
}

sub prepare_os {
    my $self = shift;

    eval { require Win32 };
    return if $@;

    my $os = $self->_os();
    $os = "$^O - " . join(" ", Win32::GetOSName());
    $os =~ s/Service\s+Pack\s+/SP/;
    $self->{__os} = $os;
}

sub __get_registry_sysinfo {
    eval { require Win32::TieRegistry };
    return if $@;

    Win32::TieRegistry->import();
    my $Registry = $Win32::TieRegistry::Registry->Open(
        "",
        { Access => 0x2000000 }
    );

    my $basekey = join(
        "\\",
        qw(LMachine HARDWARE DESCRIPTION System CentralProcessor)
    );

    my $pnskey = "$basekey\\0\\ProcessorNameString";
    my $cpustr = $Registry->{ $pnskey };

    my $idkey = "$basekey\\0\\Identifier";
    $cpustr ||= $Registry->{ $idkey };
    $cpustr =~ tr/ / /s;

    my $mhzkey = "$basekey\\0\\~MHz";
    $cpustr .= sprintf "(~%d MHz)", hex $Registry->{ $mhzkey };
    my $cpu = $cpustr;

    my $ncpu = keys %{ $Registry->{ $basekey } };

    my ($cpu_type) = $Registry->{ $idkey } =~ /^(\S+)/;

    return {
        __cpu_type  => $cpu_type,
        __cpu       => $cpu,
        __cpu_count => $ncpu,
    };
}

sub __get_environment_sysinfo {
    return {
        __cpu_type  => $ENV{PROCESSOR_ARCHITECTURE},
        __cpu       => $ENV{PROCESSOR_IDENTIFIER},
        __cpu_count => $ENV{NUMBER_OF_PROCESSORS},
    };
}

1;
