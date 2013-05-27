package Test::Smoke::LogMixin;
use warnings;
use strict;

use Exporter 'import';
our @EXPORT = qw/log_warn log_info log_debug/;

=head2 $app->log_warn($fmt, @values)

C<< prinf $fmt, @values >> to the currently selected filehandle.
=head3 Arguments

Positional.

=over

=item $fmt => a (s)printf format

The format gets an extra new line if one wasn't present.

=item @values => optional vaules for the template.

=back

=head3 Returns

use in void context.

=head3 Exceptions

None.

=cut

sub log_warn {
    my $self = shift;

    my $fmt = shift;
    $fmt .= "\n" if $fmt !~ /\n\z/;
    printf $fmt, @_;
}

=head2 $app->log_info($fmt, @values)

C<< prinf $fmt, @values >> to the currently selected filehandle if the 'verbose'
option is set.

=head3 Arguments

Positional.

=over

=item $fmt => a (s)printf format

The format gets an extra new line if one wasn't present.

=item @values => optional vaules for the template.

=back

=head3 Returns

use in void context.

=head3 Exceptions

None.

=cut

sub log_info {
    my $self = shift;
    return if !$self->v;

    my $fmt = shift;
    $fmt .= "\n" if $fmt !~ /\n\z/;
    printf $fmt, @_;
}

=head2 $app->log_debug($fmt, @values)

C<< prinf $fmt, @values >> to the currently selected filehandle if the 'verbose'
option is set to a value > 1.

=head3 Arguments

Positional.

=over

=item $fmt => a (s)printf format

The format gets an extra new line if one wasn't present.

=item @values => optional vaules for the template.

=back

=head3 Returns

use in void context.

=head3 Exceptions

None.

=cut

sub log_debug {
    my $self = shift;
    return if $self->v < 2;

    my $fmt = shift;
    $fmt .= "\n" if $fmt !~ /\n\z/;
    printf $fmt, @_;
}

1;
