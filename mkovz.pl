#!/usr/bin/perl -w

# Create matrix for smoke test results
# (c)'02 H.Merijn Brand [11 Apr 2002]
# REVISION: 1.19

# mkovz.pl [ e-mail [ folder ]]

use strict;

use Test::Smoke;
use vars qw($VERSION);
$VERSION = Test::Smoke->VERSION; 
# $Id$

use File::Spec;
use Cwd;
use Text::ParseWords;

use FindBin;
use lib $FindBin::Bin;
use lib File::Spec->catdir( $FindBin::Bin, 'lib' );
use Test::Smoke::Util qw( get_ncpu get_smoked_Config );

my $email = shift || 'daily-build-reports@perl.org';
my $testd = shift || cwd ();
my $mailer = "/usr/bin/mailx";
my $locale = shift;
my $defaultenv = shift;

my %Config = get_smoked_Config( $testd, qw( version cf_email
                                            osname osvers 
                                            cc ccversion gccversion 
                                            archname ));
my $mail_from = $Config{cf_email} ||
                ($^O eq "MSWin32" ? win32_username () : getpwuid $<);

# You can overrule the auto-detected settings here, to be more verbose
# like including the distribution: "Redhat Linux" instead of plain "linux"
#$Config{version}    ||= '5.9.0'
#$Config{osname}     ||= "MSWin32";       # hpux, AIX, cygwin, ...
#$Config{osvers}     ||= "5.0 W2000Pro";  # 11.00, 4.3.3.0, ...
#$Config{cc}         ||= "gcc";           # cc, xlc, cl, ...
#$Config{gccversion} ||= "2.95.3-6";
#$Config{archname}   ||= 'i386/1 cpu';

# clean up $Config{archname}:
$Config{archname} =~ s/-$_// 
    for qw( multi thread 64int 64all ld perlio ), $Config{osname};
$Config{archname} =~ s/^$Config{osname}(?:[.-])//i;
my $cpus = get_ncpu( $Config{osname} ) || '';
$Config{archname} .= "/$cpus" if $cpus;

my $p_version = sprintf "%d.%03d%03d", split /\./, $Config{version};
my $is56x = $p_version >= 5.006 && $p_version < 5.007;
$defaultenv ||= $is56x;

=head1 NAME

mkovz.pl - Create matrix for smoke test results.

=head1 SYNOPSYS

    $ ./mkovz.pl [ e-mail [ builddir ]]

=head1 DESCRIPTION

C<mkovz.pl> processes the output created by the C<mktest.pl> program to
create a nice report and (optionally) send it to the smokers-reports
 mailinglist.

=head2 ARGUMENTS

C<mkovz.pl> can take three (3) arguments:

=over 4

=item e-mail

This specifies the e-mailaddress to which the report is e-mailed.

You can use B<no-mail> to skip the mailing bit.

If you specify no e-mailaddress the default 
B<daily-build-reports@perl.org> is used.

=item builddir

The C<builddir> is the directory where you have just build perl and where the 
B<mktest.out> file is that C<mktest.pl> left there.

The default is the current working directory.

=item locale

It's a hack! It should be picked up from B<mktest.out>

=back

=cut

my @layers = $defaultenv ? qw( stdio ) : qw( stdio perlio );
$locale and push @layers, "locale";

my (%rpt, @confs, %confs, @manifest, $common_cfg);

local $: = " \n";
format RPT_TOP =
@||||||||||| Configuration (common) ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$rpt{patch},                        $common_cfg
~~             ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
               $common_cfg
------------ ----------------------------------------------------------------
.

my( $rpt_stat, $rpt_config );
format RPT =
@<<<<<<<<<<< ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$rpt_stat, $rpt_config
~~              (cont) ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
          $rpt_config
.

open RPT, "> " . File::Spec->catfile ($testd, "mktest.rpt")
    or die "mktest.rpt: $!";
select RPT;

my $perlio = "";
my $conf   = "";
my $debug  = "";
my %times  = ( start => undef, total => 0 );

$rpt{patch} = "?";
my ($out, @out) = (File::Spec->catfile ($testd, "mktest.out"), 1 .. 5);
open OUT, "<$out" or die "Can't open $out: $!";
for (<OUT>) {
    m/^\s*$/ and next;
    m/^-+$/  and next;

    # Buffer for broken lines (Win32, VMS)
    pop @out;
    unshift @out, $_;
    chomp $out[0];

    if ( my( $status, $time ) = /(Started|Stopped) smoke at (\d+)/ ) {
        if ( $status eq "Started" ) {
            $times{start} = $time;
        } else {
            $times{total} += ($time - $times{start}) if defined $times{start};
        }
        next;
    }
    if (m/^\s*Smoking patch (\d+)/) {
        $rpt{patch} = $1;
        next;
    }
    if (m/^MANIFEST /) {
        push @manifest, $_;
        next;
    }
    if (s/^Configuration:\s*//) {
        # Unable to build in previous conf was hidden by crash junk?
        foreach my $layer ( @layers ) {
            exists $rpt{$conf}{$debug}{$layer}
                or $rpt{$conf}{$debug}{$layer}  = "-";
        }

        s/-Dusedevel\s+//;
        $debug = s/-DDEBUGGING\s*// ? "D" : "";
        s/\s+-des//;
        s/\s+$//;
        $conf = $_ || " ";
        $confs{$_}++ or push @confs, $conf;
        next;
    }
    if (m/PERLIO\s*=\s*(\w+)/) {
        $perlio = $1;
        if ( $perlio eq 'minitest' ) {
            $rpt{$conf}{$debug}{$_} = "-" for @layers;
            $rpt{$conf}{$debug}{minitest} = "M";
            $perlio = 'stdio';
        }
        # Deal with harness output
        s/^PERLIO\s*=\s+\w+(?: :crlf)?\s*// and $out[0] = $_;
    }
    if (m/^\s*All tests successful/) {
        $rpt{$conf}{$debug}{$perlio} = $rpt{$conf}{$debug}{minitest} || "O";
        next;
    }
    if (m/^\s*Skipped this configuration/) {
	if ($^O =~ m/^(?: hpux | freebsd )$/x) {
	    (my $dup = $conf) =~ s/ -Duselongdouble//;
	    if (exists $rpt{$dup}{$debug}{stdio}) {
		@{$rpt{$conf}{$debug}}{ @layers } =
		    @{$rpt{$dup}{$debug}}{ @layers };
		next;
            }
	    $dup =~ s/ -Dusemorebits/ -Duse64bitint/;
	    if (exists $rpt{$dup}{$debug}{stdio}) {
		@{$rpt{$conf}{$debug}}{ @layers} =
		    @{$rpt{$dup}{$debug}}{ @layers };
		next;
            }
	    $dup =~ s/ -Duse64bitall/ -Duse64bitint/;
	    if (exists $rpt{$dup}{$debug}{stdio}) {
		@{$rpt{$conf}{$debug}}{ @layers } =
		    @{$rpt{$dup}{$debug}}{ @layers };
		next;
            }
        }
        foreach my $layer ( @layers ) {
            $rpt{$conf}{$debug}{ $layer }  = ".";
        }
        next;
    }
    if (m/^\s*Unable\ to\
          (?=([cbmt]))(?:build|configure|make|test)\
          (anything\ but\ mini)?perl/x) {
        $2 and $1 = uc $1; # M for no perl but miniperl
        foreach my $layer ( @layers ) {
            $rpt{$conf}{$debug}{ $layer }  = $1;
        }
        next;
    }
    # /Fix/ broken lines
    if (m/^\s*FAILED/ || m/^\s*DIED/) {
        foreach my $out (@out) {
            $out =~ m/\.\./ or next;
            ref $rpt{$conf}{$debug}{$perlio} or
                $rpt{$conf}{$debug}{$perlio} = []; # Clean up sparse garbage
            push @{$rpt{$conf}{$debug}{$perlio}}, $out . substr $_, 3;
            last;                
        }
        next;
    }
    if (m/FAILED/) {
        ref $rpt{$conf}{$debug}{$perlio} or
            $rpt{$conf}{$debug}{$perlio} = [];	# Clean up sparse garbage
        push @{$rpt{$conf}{$debug}{$perlio}}, $_;
        next;
    }
}

$Config{ccvers}	||= $Config{gccversion} || $Config{ccversion};
require Sys::Hostname;
my $this_host = Sys::Hostname::hostname() || "nohost";
my $this_pver = $^V ? sprintf "%vd", $^V : $];
$times{showtime} = time_in_hhmm( $times{total} );
my $time_msg  = $times{showtime} ? " [$times{showtime}]" : "";

print <<EOH;
Automated smoke report for $Config{version} patch $rpt{patch} on $Config{osname} - $Config{osvers} ($Config{archname})
($this_host) using $Config{cc} version $Config{ccvers}
Report by Test::Smoke v$VERSION (perl $this_pver)$time_msg

O = OK  F = Failure(s), extended report at the bottom
? = still running or test results not (yet) available
Build failures during:       - = unknown or N/A
c = Configure, m = make, M = make (after miniperl), t = make test-prep

EOH

# Determine the common Configure args
my %cfg_args;
foreach my $conf ( @confs ) {
    $cfg_args{ $_ }++ for grep defined $_ => quotewords( '\s+', 1, $conf );
}
my %common_args = map { 
    ( $_ => 1)
} grep $cfg_args{ $_ } == @confs && ! /^-[DU]use/, keys %cfg_args;

$common_cfg = join " ", sort keys %common_args;

$common_cfg ||= 'none';

my %count = ( O => 0, F => 0, M => 0, m => 0, c => 0, o => 0, t => 0);
my @fail;
for my $conf (@confs) {
    ( $rpt_stat, $rpt_config ) = ( "", $conf );
    for my $debug ("", "D") {
	for my $perlio ( @layers ) {
            my $bldenv = $perlio eq 'stdio' && 
                         $rpt{$conf}{$debug}{minitest}
                ? 'minitest' : $perlio;

	    my $res = $rpt{$conf}{$debug}{$perlio};
	    if (ref $res) {
                $rpt_stat .= $bldenv eq 'minitest' ? "M " : "F ";
		my $s_conf = $conf;
		$debug and substr ($s_conf, 0, 0) = "-DDEBUGGING ";
		if ( $perlio eq "stdio" && ref $rpt{$conf}{$debug}{perlio} 
                     && "@{$rpt{$conf}{$debug}{perlio}}" 
                     eq "@{$rpt{$conf}{$debug}{stdio}}" ) {
		    # Squeeze stdio/perlio errors together
		    push @fail, [ "stdio/perlio", $s_conf, $res ];
		    next;
		} elsif ( $bldenv eq "perlio" && ref $rpt{$conf}{$debug}{stdio}
                          && "@{ $rpt{$conf}{$debug}{stdio} }"
                          eq "@{ $rpt{$conf}{$debug}{perlio} }" ) {
                    next;
                } elsif ( $bldenv eq "locale" ) {
                    push @fail, [ "locale:$locale", $s_conf, $res ];
                    next;
                }
		push @fail, [ $bldenv, $s_conf, $res ];
		next;
	    }
            $rpt_stat .= ( $res ? $res : "?" ) . " ";
	}
    }
    $rpt_config = join " ", grep defined $_ && !exists $common_args{ $_ }, 
                            quotewords( '\s+', 1, $conf );
    write;
    # special casing the '-' should change PASS-so-far
    # to PASS if the report only has 'O' and '-'
    $count{ $_ }++ for map { 
        /[OFMmct]/ ? $_ : /-/ ? 'O' : 'o'
    } split ' ', $rpt_stat;
}

my @rpt_sum_stat = grep $count{ $_ } > 0 => qw( F M m c t );
my $rpt_summary = '';
if ( @rpt_sum_stat ) {
    $rpt_summary = "FAIL(" . join( "", @rpt_sum_stat ) . ")";
} else {
    $rpt_summary = $count{o} == 0 ? 'PASS' : 'PASS-so-far';
}

print $locale ? <<EOL : $defaultenv ? <<EOS : <<EOE;
| | | | | +- LC_ALL = $locale -DDEBUGGING
| | | | +--- PERLIO = perlio -DDEBUGGING
| | | +----- PERLIO = stdio  -DDEBUGGING
| | +------- LC_ALL = $locale
| +--------- PERLIO = perlio
+----------- PERLIO = stdio

Summary: $rpt_summary

EOL
| +--------- -DDEBUGGING
+----------- no debugging

Summary: $rpt_summary

EOS
| | | +----- PERLIO = perlio -DDEBUGGING
| | +------- PERLIO = stdio  -DDEBUGGING
| +--------- PERLIO = perlio
+----------- PERLIO = stdio

Summary: $rpt_summary

EOE

if ( @fail ) {
    my $rpt_pio;
format RPT_Fail_Config =
@<<<<<<<<<<<[@<<<<<<<<<<<]^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$^O,         $rpt_pio,    $rpt_config
~~            (cont) ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
                     $rpt_config
.

    $^ = 'STDOUT_TOP';
    $~ = 'RPT_Fail_Config';
    print "\nFailures:\n\n";
    for my $i (0 .. $#fail) {
        my $ref = $fail[$i];
        ( $rpt_pio, $rpt_config ) = @{ $ref }[0, 1];
        write;
        if ($i < $#fail) { # More squeezing
	    my $nref = $fail[$i + 1];
            $ref->[0] =~  /\Q$nref->[0]\E/ and
                "@{$ref->[-1]}" eq "@{$nref->[-1]}" and next;
        }
    print @{$ref->[-1]}, "\n";
    }
}

@manifest and print RPT "\n\n", @manifest;

close RPT;
select STDOUT;

send_mail () unless $email =~ /^no\-?e?mail$/i;

sub send_mail
{
    my $subject = "Smoke [$Config{version}] $rpt{patch} $rpt_summary ".
                  "$Config{osname} $Config{osvers} ($Config{archname})";
    if ($mailer =~ m/sendmail/) {
        local (*MAIL, *BODY, $/);
        open  BODY, "<" . File::Spec->catfile ($testd, "mktest.rpt");
        open  MAIL, "| $mailer -i -t";
        print MAIL join "\n",
	    "To: $email",
	    "From: $mail_from",
	    "Subject: $subject",
	    "",
	    <BODY>;
        close BODY;
        close MAIL;
        }
    else {
        system "$mailer -s '$subject' $email < " . 
               File::Spec->catfile ($testd, "mktest.rpt");
        }
    } # send_mail

sub win32_username 
{
    # Are we on nontoy Windows?
    my $user = $ENV{USERNAME};
    $user and return $user;

    # We'll try from Win32.pm
    eval { require Win32; } ;
    $@ and return 'unknown';
    return Win32::LoginName() || 'unknown';
} # win32_username

sub time_in_hhmm {
    my $diff = shift;

    my $digits = $diff =~ /\./ ? 3 : 0;
    my $days = int( $diff / (24*60*60) );
    $diff -= 24*60*60 * $days;
    my $hour = int( $diff / (60*60) );
    $diff -= 60*60 * $hour;
    my $mins = int( $diff / 60 );
    $diff -=  60 * $mins;

    my @parts;
    $days and push @parts, sprintf "%d day%s",   $days, $days == 1 ? "" : 's';
    $hour and push @parts, sprintf "%d hour%s",  $hour, $hour == 1 ? "" : 's';
    $mins and push @parts, sprintf "%d minute%s",$mins, $mins == 1 ? "" : 's';
    $diff && !$days && !$hour and
        push @parts, sprintf "%.${digits}f seconds", $diff;

    return join " ", @parts;
}

=head1 CHANGES

For more recent changes see B<ChangeLog>.

1.14
    - Changed part of the report printing to use a format (write) 
    - switch back the <email> <testdir> args that Merijn accidentally swapped
    - Be a bit more subtile about Win32 username
    - Don't die() when lib/Config.pm isn't found

1.13
    - Moved part of Config to top for easier user changes

1.12
    - Use Config.pm of the smoked perl
    - A bit more Win32 minded :-)

=head1 COPYRIGHT

(c) 2002-2003, All rights reserved.

  * H.Merijn Brand <h.m.brand@hccnet.nl>
  * Abe Timmerman <abeltje@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See:

=over 4

=item * http://www.perl.com/perl/misc/Artistic.html

=item * http://www.gnu.org/copyleft/gpl.html

=back

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
