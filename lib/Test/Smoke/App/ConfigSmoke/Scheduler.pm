package Test::Smoke::App::ConfigSmoke::Scheduler;
use warnings;
use strict;

use Exporter 'import';
our @EXPORT = qw/ config_scheduler schedule_entry_ms_at schedule_entry_crontab /;

use Test::Smoke::App::Options;
use Test::Smoke::Util::FindHelpers 'whereis';

=head1 NAME

Test::Smoke::App::ConfigSmoke::Scheduler - Mixin for L<Test::Smoke::App::ConfigSmoke>

=head1 DESCRIPTION

These methods will be added to the L<Test::Smoke::App::ConfigSmoke> class.

=head2 config_scheduler

Configure options C<hostname>, C<usernote> and C<usernote_pos>

=cut

sub config_scheduler {
    my $self = shift;
    return if $^O eq 'VMS';

    print "\n-- Scheduler section --\n";

    my ($cronbin, $has_crond) = get_avail_scheduler();

    if (not $cronbin) {
        print "!!!!!\nCannot find a scheduler.\n!!!!!\n";
        return;
    }

    $self->current_values->{cronbin} = $cronbin;
    my $docron = $self->handle_option(docron_option($cronbin));
    return unless $docron;

    my $crontime = $self->handle_option(crontime_option());

    my @current_cron;
    if ($^O eq 'MSWin32') {
        $self->{_jcl} = $self->prefix . '.cmd';
        $self->{_jcl_abs} = Cwd::abs_path($self->jcl);
        if ($cronbin =~ m{schtasks}i) {

            my $new_entry = $self->schedule_entry_ms_at($cronbin, $crontime);
            my $add2cron = $self->handle_option(add2cron_option($new_entry));

            system $new_entry if $add2cron;
        }
        elsif (open(my $crontab, "$cronbin |")) {
            @current_cron = <$crontab>;
            close($crontab) or warn "Error reading schedule: $!\n";

            @current_cron = grep { m{^\s+\d+\s+.+\d+:\d+\s/} } @current_cron;

            my $new_entry = $self->schedule_entry_ms_at($cronbin, $crontime);
            my $add2cron = $self->handle_option(add2cron_option($new_entry));

            system $new_entry if $add2cron;
        }
        else {
            print "!!!!!\nError reading current schedual(fork): $!\n!!!!!\n";
            print "Please, fix this yourself.\n";
        }
    }
    else {
        my $jcl = $self->{_jcl} = $self->prefix . '.sh';
        $self->{_jcl_abs} = Cwd::abs_path($self->jcl);
        if (open(my $crontab, "$cronbin -l |")) {
            @current_cron = <$crontab>;
            close($crontab) or warn "Error reading schedule: $!\n";

            if ( "@current_cron" =~ m{^# DO NOT EDIT THIS FILE} ) {
                splice @current_cron, 0, 3;
            }

            my $new_entry = $self->schedule_entry_crontab($cronbin, $crontime);
            @current_cron = grep { $_ !~ m{^$new_entry$} } @current_cron;
            s{^ (?<!\#) \s* (.+?(?:$jcl)) }{# $1}x for @current_cron;

            my $cronout_file = $self->prefix . '.crontab';
            if (open(my $cronout, '>', $cronout_file)) {
                print {$cronout} $_ for @current_cron;
                print {$cronout} "\n# Test::Smoke\n$new_entry\n";
                close($cronout);
                print "\n    >> Created '$cronout_file'.\n";

                my $add2cron = $self->handle_option(add2cron_option($new_entry));
                system($cronbin, $cronout_file) if $add2cron;
            }
            else {
                print "!!!!!\nError creating($cronout_file): $!\n!!!!!\n";
                print "Please, fix this yourself.\n";
            }
        }
        else {
            print "!!!!!\nError reading current schedual(fork): $!\n!!!!!\n";
            print "Please, fix this yourself.\n";
        }
    }
}

=head2 get_avail_scheduler

Looks for F<at.exe> on C<MSWin32> or F<cron(tab)> on other systems.

=cut

sub get_avail_scheduler {
    my( $scheduler, $has_crond );

    if ( $^O eq 'MSWin32' ) { # We're looking for 'SchTasks.exe' or 'at.exe'
        $scheduler = whereis( 'schtasks') || whereis( 'at' );
    }
    else { # We're looking for 'crontab' or 'cron'
        $scheduler = whereis( 'crontab' ) || whereis( 'cron' );
        ( $has_crond ) = grep /\bcrond?\b/ => `ps -e`;
    }
    return ( $scheduler, $has_crond );
}

=head2 schedule_entry_ms_schtasks

Return an etry for MS-C<SchTasks>

=cut

sub schedule_entry_ms_schtasks {
    my $self = shift;
    my ($cron, $crontime) = @_;
    my $script = $self->jcl_abs;

    return '' unless $crontime;

    return sprintf(
        qq[%s /Create /SC DAILY /ST %s /TN P5SmokeRun /TR "%s"],
        $cron, $crontime, $script
    );
}

=head2 schedule_entry_ms_at

Return an entry for MS-C<AT>.

=cut

sub schedule_entry_ms_at {
    my $self = shift;
    my ($cron, $crontime) = @_;
    my $script = $self->jcl;

    return '' unless $crontime;
    my ($hour, $min) = $crontime =~ /(\d+):(\d+)/;


    return sprintf(
        qq[$cron %02d:%02d /EVERY:M,T,W,Th,F,S,Su "%s"],
        $hour, $min, $self->jcl_abs
    );
}

=head2 schedule_entry_crontab

Return an entry for C<crontab(5)> (3 stars)

=cut

sub schedule_entry_crontab {
    my $self = shift;
    my ($cron, $crontime) = @_;

    return '' unless $crontime;
    my ($hour, $min) = $crontime =~ /(\d+):(\d+)/;

    return sprintf(qq[%02d %02d * * * '%s'], $min, $hour, $self->jcl_abs);
}

=head2 docron_option

This option C<docron> is not in the config-file, but is only needed to continue
on the scheduler path.

=cut

sub docron_option {
    my ($scheduler) = @_;
    return Test::Smoke::App::AppOption->new(
        name       => 'docron',
        allow      => undef,
        default    => 0,
        helptext   => "I see you have '$scheduler'\n",
        configtext => 'Should the smoke be scheduled?',
        configtype => 'prompt_yn',
        configalt  => sub { [qw/ N y /] },
        configdft  => sub {'N'},
    );
}

=head2 crontime_option

This option C<crontime> will be in the config-file, but only as a reminder.

=cut

sub crontime_option {
    return Test::Smoke::App::AppOption->new(
        name      => 'crontime',
        helptext  => 'At what time should the smoke be scheduled?',
        configdft => sub { '22:25' },
        chk       => '(?:random|(?:[012]?\d:[0-5]?\d))',
    );
}

=head2 add2cron_option

This option C<add2cron> will not be in the config-file.

=cut

sub add2cron_option {
    my ($new_entry) = @_;
    return Test::Smoke::App::AppOption->new(
        name => 'add2cron',
        configtext => "Add this line to your schedule?\n\t$new_entry\n",
        configtype => 'prompt_yn',
        configalt => sub { [qw/ Y n /] },
        configdft => sub { 'Y' },
    );
}

1;

=head1 COPYRIGHT

(c) 2020, All rights reserved.

  * Abe Timmerman <abeltje@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See:

=over 4

=item * L<http://www.perl.com/perl/misc/Artistic.html>

=item * L<http://www.gnu.org/copyleft/gpl.html>

=back

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

