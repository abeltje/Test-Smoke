package Test::Smoke::SysInfo::Haiku;
use warnings;
use strict;

use base 'Test::Smoke::SysInfo::Base';

sub prepare_sysinfo {
    my $self = shift;
    $self->SUPER::prepare_sysinfo();

    eval { local $^W = 0; require Haiku::SysInfo };
    return $self if $@;

    my $hsi = Haiku::SysInfo->new();
    my $gh = 1_000_000_000;
    (my $cbs = $hsi->cpu_brand_string) =~ s/^\s+//;
    $self->{__cpu_type}  = $cbs;
    $self->{__cpu}       = sprintf( "%d", $hsi->cpu_type );
    $self->{__cpu_count} = $hsi->cpu_count;

    $self->{__os}       = sprintf("%s %s",$hsi->kernel_name, $hsi->kernel_version);
    return $self;
}

1;
