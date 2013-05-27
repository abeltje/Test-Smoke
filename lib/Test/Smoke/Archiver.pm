package Test::Smoke::Archiver;
use warnings;
use strict;

use base 'Test::Smoke::ObjectBase';
use Test::Smoke::LogMixin;

use File::Copy;
use File::Path;
use File::Spec::Functions;
use Test::Smoke::Util qw/get_patch/;

my %CONFIG = (
    df_archive => 1,
    df_ddir    => '.',
    df_adir    => undef,

    df_outfile => 'mktest.out',
    df_rptfile => 'mktest.rpt',
    df_jsnfile => 'mktest.jsn',
    df_lfile   => undef,

    df_v => 0,
);

sub new {
    my $class = shift;
    my %args = @_;

    my %struct;
    for my $dfkey (keys %CONFIG) {
        (my $key = $dfkey) =~ s/^df_//;
        $struct{"_$key"} = exists $args{$key} ? $args{$key} : $CONFIG{$dfkey};
    }

    my $self = bless \%struct, $class;

    return $self;
}

sub archive_files {
    my $self = shift;
    if (!$self->archive) {
        return $self->log_info("Skipping archive: --noarchive.");
    }
    if (!$self->adir) {
        return $self->log_info("Skipping archive: No archive directory set.");
    }
    
    if (!-d $self->adir) {
        mkpath($self->adir, ($self->v > 1), 0775)
            or die "Cannot mkpath(@{[$self->adir]}): $!";
    }

    (my $patch_level = get_patch($self->ddir)->[0]) =~ tr/ //sd;
    $self->{_patchlevel} = $patch_level;

    for my $filetype (qw/rpt out jsn log/) {
        my $to_archive = "archive_$filetype";
        $self->$to_archive;
    }
}

sub archive_rpt {
    my $self = shift;
    my $src = catfile($self->ddir, $self->rptfile);
    if (! -f $src) {
        return $self->log_info("%s not found: skip archive rpt", $src);
    }
    my $dst = catfile($self->adir, sprintf("rpt%s.rpt", $self->patchlevel));
    if (-f $dst) {
        return $self->log_info("%s exits, skip archive rpt", $dst);
    }

    my $success = copy($src, $dst);
    if (!$success) {
        $self->log_warn("Failed to cp(%s,%s): %s", $src, $dst, $!);
    }
    else {
        $self->log_info("Copy(%s, %s): ok", $src, $dst);
    }
    return $success;
}

sub archive_out {
    my $self = shift;
    my $src = catfile($self->ddir, $self->outfile);
    if (! -f $src) {
        return $self->log_info("%s not found: skip archive out", $src);
    }
    my $dst = catfile($self->adir, sprintf("out%s.out", $self->patchlevel));
    if (-f $dst) {
        return $self->log_info("%s exits, skip archive out", $dst);
    }

    my $success = copy($src, $dst);
    if (!$success) {
        $self->log_warn("Failed to cp(%s,%s): %s", $src, $dst, $!);
    }
    else {
        $self->log_info("Copy(%s, %s): ok", $src, $dst);
    }
    return $success;
}

sub archive_jsn {
    my $self = shift;
    my $src = catfile($self->ddir, $self->jsnfile);
    if (! -f $src) {
        return $self->log_info("%s not found: skip archive jsn", $src);
    }
    my $dst = catfile($self->adir, sprintf("jsn%s.jsn", $self->patchlevel));
    if (-f $dst) {
        return $self->log_info("%s exits, skip archive jsn", $dst);
    }

    my $success = copy($src, $dst);
    if (!$success) {
        $self->log_warn("Failed to cp(%s,%s): %s", $src, $dst, $!);
    }
    else {
        $self->log_info("Copy(%s, %s): ok", $src, $dst);
    }
    return $success;
}

sub archive_log {
    my $self = shift;
    my $src = $self->lfile;
    if (! -f $src) {
        return $self->log_info("%s not found: skip archive log", $src);
    }
    my $dst = catfile($self->adir, sprintf("log%s.log", $self->patchlevel));
    if (-f $dst) {
        return $self->log_info("%s exits, skip archive log", $dst);
    }

    my $success = copy($src, $dst);
    if (!$success) {
        $self->log_warn("Failed to cp(%s,%s): %s", $src, $dst, $!);
    }
    else {
        $self->log_info("Copy(%s, %s): ok", $src, $dst);
    }
    return $success;
}

1;
