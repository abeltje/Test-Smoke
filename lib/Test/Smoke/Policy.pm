package Test::Smoke::Policy;
use strict;

use vars qw( $VERSION );
$VERSION = '0.002'; # $Id$

use File::Spec;

=head1 NAME

Test::Smoke::Policy - OO interface to handle the Policy.sh stuff.

=head1 SYNOPSIS

    use Test::Smoke::Policy;

    my $srcpath = File::Spec->updir;
    my $policy = Test::Smoke::Policy->new( $srcpath );

    $policy->substitute( [] );
    $policy->write;

=head1 DESCRIPTION

I wish I understood what Merijn is doeing in the original code.

=head1 METHODS

=over 4

=item Test::Smoke::Policy->new( $srcpath )

Create a new instance of the Policy object.
Read the file or take data from the DATA section.

=cut

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;

    my $self = bless { }, $class;
    $self->reset_rules;
    $self->_read_Policy( @_ );
    $self;
}

=item $object->set_rules( $rules )

Set the rules for substitutions.

=cut

sub set_rules {
    my( $self, $rules ) = @_;

    push @{ $self->{_rules} }, $rules;
}

=item $object->reset_rules( )

Reset the C<_rules> property.

=cut

sub reset_rules {
    $_[0]->{_rules} = [ ];
    $_[0]->{_new_policy} = undef;
}

=item $Policy->_do_subst( )

C<_do_subst()> does the substitutions and stores the substituted version
as the B<_new_policy> attribute.

=cut

sub _do_subst {
    my $self = shift;

    my %substs;
    foreach my $rule ( @{ $self->{_rules} } ) {
        push @{ $substs{ $rule->[0] } }, $rule->[1];
    }
    my $policy = $self->{_policy};
    while ( my( $target, $values ) = each %substs ) {
        unless ( $policy =~ s{^(\s*ccflags=.*?)$target}
                             {$1 . join " ", 
                                   grep $_ && length $_ => @$values}meg ) {
            require Carp;
            Carp::carp "Policy target '$target' failed to match";
        }
    }
    $self->{_new_policy} = $policy;
}

=item $object->write( )

=cut

sub write {
    my $self = shift;

    defined $self->{_new_policy} or $self->_do_subst;

    local *POL;
    my $p_name = shift || 'Policy.sh';
    unlink $p_name; # or carp "Can't unlink '$p_name': $!";
    if ( open POL, "> $p_name" ) {
        print POL $self->{_new_policy};
        close POL or do {
            require Carp;
            Carp::carp "Error rewriting '$p_name': $!";
        };
    } else {
        require Carp;
        Carp::carp "Unable to rewrite '$p_name': $!";
    }
}

=item $self->_read_Policy( $srcpath )

C<_read_Policy()> checks the C<< $srcpath >> for these conditions:

=over 4

=item B<Reference to a SCALAR> Policy is in C<$$srcpath>

=item B<Reference to an ARRAY> Policy is in C<@$srcpath>

=item B<Reference to a GLOB> Policy is read from the filehandle

=item B<Other values> are taken as the base path for F<Policy.sh>

=back

=cut

sub _read_Policy {
    my( $self, $srcpath, $verbose ) = @_;
    $srcpath = '' unless defined $srcpath;

    $self->{v} ||= defined $verbose ? $verbose : 0;
    my $vmsg = "";
    local *POLICY;
    if ( ref $srcpath eq 'SCALAR' ) {

        $self->{_policy} = $$srcpath;
        $vmsg = "internal content";

    } elsif ( ref $srcpath eq 'ARRAY' ) {

        $self->{_poliy} = join "", @$srcpath;
        $vmsg = "internal content";

    } elsif ( ref $srcpath eq 'GLOB' ) {

        *POLICY = *$srcpath;
        $self->{_policy} = do { local $/; <POLICY> };
        $vmsg = "anonymous filehandle";

    } else {
        $srcpath = File::Spec->curdir 
            unless defined $srcpath && length $srcpath;
        my $p_name = File::Spec->catfile( $srcpath, 'Policy.sh' );

        unless ( open POLICY, $p_name ) {
            *POLICY = *DATA{IO};
            $vmsg = "default content";
        } else {
            $vmsg = $p_name;
        }

        $self->{_policy} = do { local $/; <POLICY> };
        close POLICY;
    }
    $self->{v} and print "Reading 'Policy.sh' from $vmsg($self->{v})\n";
}
 
1;

=back

=head1 COPYRIGHT

(c) 2001-2003, All rights reserved.

  * H.Merijn Brand <hmbrand@hccnet.nl>
  * Nicholas Clark <nick@unfortu.net>
  * Abe Timmerman <abeltje@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See:

  * <http://www.perl.com/perl/misc/Artistic.html>,
  * <http://www.gnu.org/copyleft/gpl.html>

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

__DATA__
#!/bin/sh

# Default Policy.sh

# Be sure to define -DDEBUGGING by default, it's easier to remove
# it from Policy.sh than it is to add it in on the correct places

ccflags='-DDEBUGGING'
