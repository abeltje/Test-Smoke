package Test::Smoke::App::SendReport;
use warnings;
use strict;

use base 'Test::Smoke::App::Base';

use File::Spec::Functions;
use Test::Smoke::Mailer;
use Test::Smoke::Poster;
use Test::Smoke::Reporter;

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    if ($self->option('mail')) {
        $self->{_mailer} = Test::Smoke::Mailer->new(
            $self->option('mail_type'),
            $self->options,
            v => $self->option('verbose'),
        );
    }
    else {
        $self->log_info("Skipped sending mail.");
    }
    $self->{_poster} = Test::Smoke::Poster->new(
        $self->option('poster'),
        $self->options,
        v => $self->option('verbose'),
    );

    return $self;
}

sub run {
    my $self = shift;

    $self->check_for_report_and_json;

    if ($self->option('mail')) {
        $self->mailer->mail();
    }

    if ($self->option('smokedb_url')) {
        $self->poster->post();
    }
}

sub check_for_report_and_json {
    my $self = shift;

    my $rptfile = catfile($self->option('ddir'), $self->option('rptfile'));
    my $jsnfile = catfile($self->option('ddir'), $self->option('jsnfile'));
    my $missing = 0;
    if (!-f $rptfile) {
        $self->log_info("RPTfile ($rptfile) not found");
        $missing = 1;
    }
    else {
        $self->log_debug("RPTfile (%s) found.", $rptfile);
    }
    if (!-f $jsnfile) {
        $self->log_info("JSNfile ($jsnfile) not found");
        $missing = 1;
    }
    else {
        $self->log_debug("JSNfile (%s) found.", $jsnfile);
    }
    if ($missing || $self->option('report')) {
        $self->log_info("Regenerate report and json.");
        $self->regen_report_and_json();
    }
    return 1;
}

sub regen_report_and_json {
    my $self = shift;

    my $outfile = catfile($self->option('ddir'), $self->option('outfile'));
    if (!-f $outfile) {
        die "No smoke results found ($outfile)\n";
    }
    my $reporter = Test::Smoke::Reporter->new(
        $self->options,
        v => $self->option('verbose'),
    );
    $self->log_debug("[Reporter] write_to_file()");
    $reporter->write_to_file();
    $self->log_debug("[Reporter] smokedb_data()");
    $reporter->smokedb_data();

    return 1;
}

1;
