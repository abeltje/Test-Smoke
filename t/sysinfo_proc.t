#! perl -w
use strict;

# $Id$
use Test::More;

# 5.005xx doesn't support three argumented open()
# 5.6 has trouble with TIEHANDLE
BEGIN {
    plan $] < 5.008
        ? ( skip_all => "Tests not supported on $]" )
        : ( tests => 4 );
}

my %files;
BEGIN {
    # redefine the CORE functions to mimic themselfs at compile-time
    # so we can re-redefine them at run-time
    *CORE::GLOBAL::open = sub (*;$@) {
        my( $handle, $second, @args ) = @_;
        if ( defined $handle && ! ref $handle ) {
            my( $pkg ) = caller;
            no strict 'refs';
            $handle = \*{ "$pkg\:\:$handle" };
        }
        CORE::open $handle, $second, @args;
    };

    *CORE::GLOBAL::close = sub (*) {
        my( $handle ) = @_;
        unless ( ref $handle ) {
            my( $pkg ) = caller;
            no strict 'refs';
            $handle = *{ "$pkg\:\:$handle" };
        }
        CORE::close $handle;
    };
}

use_ok 'Test::Smoke::SysInfo';
my $this_system = Test::Smoke::SysInfo::Generic();

{
    # redefine the CORE functions only locally
    local $^W; # no warnings 'redefine';
    local *CORE::GLOBAL::open = sub (*;$@) {
        local $^W = 1;
        my( $handle, $second, @args ) = @_;
        if ( defined $handle && ! ref $handle ) {
            my( $pkg ) = caller;
            no strict 'refs';
            $handle = *{ "$pkg\:\:$handle" };
        }

        if ( $second eq '< /proc/cpuinfo' ) {
            my $fn = Test::Smoke::SysInfo::__get_cpu_type();

            # we can do this fully qualified filehandle as we only use GLOBs
            # to keep up with 5.005xx
            no strict 'refs';
            tie *$handle, 'ReadProc', $files{ $fn };
        } else {
            CORE::open \$handle, $second, @args;
        }
    };
    local *CORE::GLOBAL::close = sub (*) {
        my( $pkg ) = caller;
        no strict 'refs';
        untie *{ "$pkg\:\:$_[0]" };
    };
    *Test::Smoke::SysInfo::__get_cpu_type = sub { 'i386' };
    $^W = 1;

    my $i386 = Test::Smoke::SysInfo::Linux();

    is_deeply $i386, {
        _host     => $this_system->{_host},
        _os       => $this_system->{_os},
        _cpu_type => 'i386',
        _cpu      => 'AMD Athlon(tm) 64 Processor 3200+ (AuthenticAMD 1000MHz)',
        _ncpu     => 1,
    }, "Read /proc/cpuinfo for i386";


    $^W = 0;
    *Test::Smoke::SysInfo::__get_cpu_type = sub { 'ppc' };
    $^W = 1;

    my $ppc = Test::Smoke::SysInfo::Linux();

    is_deeply $ppc, {
        _host     => $this_system->{_host},
        _os       => $this_system->{_os},
        _cpu_type => 'ppc',
        _cpu      => '7400, altivec supported PowerMac G4 (400.000000MHz)',
        _ncpu     => 1,
    }, "Read /proc/cpuinfo for ppc";

    $^W = 0;
    *Test::Smoke::SysInfo::__get_cpu_type = sub { 'i386_2' };
    $^W = 1;

    my $i386_2 = Test::Smoke::SysInfo::Linux();

    is_deeply $i386_2, {
        _host     => $this_system->{_host},
        _os       => $this_system->{_os},
        _cpu_type => 'i386_2',
        _cpu      => 'Intel(R) Core(TM)2 CPU T5600 @ 1.83GHz (GenuineIntel 1000MHz)',
        _ncpu     => 2,
    }, "Read /proc/cpuinfo for duo i386";
}

# Assign file contents
BEGIN {
    $files{i386} = <<__EOINFO__;
processor       : 0
vendor_id       : AuthenticAMD
cpu family      : 15
model           : 47
model name      : AMD Athlon(tm) 64 Processor 3200+
stepping        : 2
cpu MHz         : 1000.000
cache size      : 512 KB
fdiv_bug        : no
hlt_bug         : no
f00f_bug        : no
coma_bug        : no
fpu             : yes
fpu_exception   : yes
cpuid level     : 1
wp              : yes
flags           : fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush mmx fxsr sse sse2 syscall nx mmxext fxsr_opt lm 3dnowext 3dnow up pni lahf_lm ts fid vid ttp tm stc
bogomips        : 2012.54
__EOINFO__

    $files{ppc} = <<__EOINFO__;
processor       : 0
cpu             : 7400, altivec supported
temperature     : 20-29 C (uncalibrated)
clock           : 400.000000MHz
revision        : 2.9 (pvr 000c 0209)
bogomips        : 49.66
timebase        : 24908033
machine         : PowerMac3,1
motherboard     : PowerMac3,1 MacRISC Power Macintosh
detected as     : 65 (PowerMac G4 AGP Graphics)
pmac flags      : 00000004
L2 cache        : 1024K unified
pmac-generation : NewWorld
__EOINFO__

    $files{i386_2} = <<__EOINFO__;
processor	: 0
vendor_id	: GenuineIntel
cpu family	: 6
model		: 15
model name	: Intel(R) Core(TM)2 CPU         T5600  @ 1.83GHz
stepping	: 6
cpu MHz		: 1000.000
cache size	: 2048 KB
physical id	: 0
siblings	: 2
core id		: 0
cpu cores	: 2
fdiv_bug	: no
hlt_bug		: no
f00f_bug	: no
coma_bug	: no
fpu		: yes
fpu_exception	: yes
cpuid level	: 10
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe nx lm constant_tsc pni monitor ds_cpl vmx est tm2 ssse3 cx16 xtpr lahf_lm
bogomips	: 3661.63
clflush size	: 64

processor	: 1
vendor_id	: GenuineIntel
cpu family	: 6
model		: 15
model name	: Intel(R) Core(TM)2 CPU         T5600  @ 1.83GHz
stepping	: 6
cpu MHz		: 1833.000
cache size	: 2048 KB
physical id	: 0
siblings	: 2
core id		: 1
cpu cores	: 2
fdiv_bug	: no
hlt_bug		: no
f00f_bug	: no
coma_bug	: no
fpu		: yes
fpu_exception	: yes
cpuid level	: 10
wp		: yes
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe nx lm constant_tsc pni monitor ds_cpl vmx est tm2 ssse3 cx16 xtpr lahf_lm
bogomips	: 3657.62
clflush size	: 64
__EOINFO__
}

package ReadProc;

sub TIEHANDLE {
    my $class = shift;
    my $data  = shift or die "No content for tied filehandle!";
    bless \$data, $class;
}

sub READLINE {
    my $buffer = shift;
    length $$buffer or return;
    if ( wantarray ) {
        my @list = map "$_\n" => split m/\n/, $$buffer;
        $$buffer = "";
        return @list;
    } else {
        $$buffer =~ s/^(.*\n?)// and return $1;
    }
}

1;
