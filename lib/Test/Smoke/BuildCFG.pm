package Test::Smoke::BuildCFG;
use strict;

# $Id$
use vars qw( $VERSION );
$VERSION = '0.002';

use Cwd;
use File::Spec;
require File::Path;

my %CONFIG = (
    df_v      => 0,
    df_dfopts => '-Dusedevel',
);

=head1 NAME

Test::Smoke::BuildCFG - OO interface for handling build configurations

=head1 SYNOPSIS

    use Test::Smoke::BuildCFG;

    my $name = 'perlcurrent.cfg';
    my $bcfg = Test::Smoke::BuildCFG->new( $name );

    foreach my $config ( $bcfg->configurations ) {
        # do somthing with $config
    }

=head1 DESCRIPTION

Handle the build configurations

=head1 METHODS

=over 4

=cut

=item Test::Smoke::BuildCFG->new( [$cfgname] )

[ Constructor | Public ]

Initialise a new object.

=cut

sub new {
    my $proto = shift;
    my $class = ref $proto ? ref $proto : $proto;

    my $config = shift;

    my %args_raw = @_ ? UNIVERSAL::isa( $_[0], 'HASH' ) ? %{ $_[0] } : @_ : ();

    my %args = map {
        ( my $key = $_ ) =~ s/^-?(.+)$/lc $1/e;
        ( $key => $args_raw{ $_ } );
    } keys %args_raw;

    my %fields = map {
        my $value = exists $args{$_} ? $args{ $_ } : $CONFIG{ "df_$_" };
        ( $_ => $value )
    } qw( v dfopts );

    my $self = bless \%fields, $class;
    $self->read_parse( $config );
}

=item Test::Smoke::BuildCFG->config( $key[, $value] )

[ Accessor | Public ]

C<config()> is an interface to the package lexical C<%CONFIG>, 
which holds all the default values for the C<new()> arguments.

With the special key B<all_defaults> this returns a reference
to a hash holding all the default values.

=cut

sub config {
    my $dummy = shift;

    my $key = lc shift;

    if ( $key eq 'all_defaults' ) {
        my %default = map {
            my( $pass_key ) = $_ =~ /^df_(.+)/;
            ( $pass_key => $CONFIG{ $_ } );
        } grep /^df_/ => keys %CONFIG;
        return \%default;
    }

    return undef unless exists $CONFIG{ "df_$key" };

    $CONFIG{ "df_$key" } = shift if @_;

    return $CONFIG{ "df_$key" };
}

=item $self->read_parse( $cfgname )

C<read_parse()> reads the build configurations file and parses it.

=cut

sub read_parse {
    my $self = shift;

    $self->_read( @_ );
    $self->_parse;

    return $self;
}

=item $self->_read( $nameorref )

C<_read()> is a private method that handles the reading.

=over 4

=item B<Reference to a SCALAR> build configurations are in C<$$nameorref>

=item B<Reference to an ARRAY> build configurations are in C<@$nameorref>

=item B<Reference to a GLOB> build configurations are read from the filehandle

=item B<Other values> are taken as the filename for the build configurations

=back

=cut

sub _read {
    my $self = shift;
    my( $nameorref ) = @_;
    $nameorref = '' unless defined $nameorref;

    my $vmsg = "";
    local *BUILDCFG;
    if ( ref $nameorref eq 'SCALAR' ) {
        $self->{_buildcfg} = $$nameorref;
        $vmsg = "internal content";
    } elsif ( ref $nameorref eq 'ARRAY' ) {
        $self->{_buildcfg} = join "", @$nameorref;
        $vmsg = "internal content";
    } elsif ( ref $nameorref eq 'HASH' ) {
        $self->{_buildcfg} = undef;
        $self->{_list} = $nameorref->{_list};
        $vmsg = "continuing smoke";
    } elsif ( ref $nameorref eq 'GLOB' ) {
	*BUILDCFG = *$nameorref;
        $self->{_buildcfg} = do { local $/; <BUILDCFG> };
        $vmsg = "anonymous filehandle";
    } else {
        unless ( open BUILDCFG, "< $nameorref" ) {
            require Carp;
            Carp::carp "Error opening buildconfigurations: $!";
            my $dft = $self->default_buildcfg();
            return $self->_read( \$dft );
        }
        $self->{_buildcfg} = do { local $/; <BUILDCFG> };
        close BUILDCFG;
        $vmsg = $nameorref;
    }
    $self->{v} and print "Reading build configurations from $vmsg\n";
}

=item $self->_parse( )

C<_parse()> will split the build configurations file in sections.
Sections are ended with a line that begins with an equals-sign ('=').

There are two types of section

=over 8

=item B<buildopt-section>

=item B<policy-section>

A B<policy-section> contains a "target-option". This is a build option 
that should be in the ccflags variable in the F<Policy.sh> file 
(see also L<Test::Smoke::Policy>) and starts with a (forward) slash ('/').

A B<policy-section> can have only one (1) target-option.

=back

=cut

sub _parse {
    my $self = shift;

    return unless defined $self->{_buildcfg}; # || $self->{_list};

    $self->{_sections} = [ ];
    my @sections = split m/^=.*\n/m, $self->{_buildcfg};
    $self->{v} > 1 and printf "Found %d raw-sections\n", scalar @sections;

    foreach my $section ( @sections ) {
        my $index = 0;
        my %opts = map { $_ => $index++ } map { s/^\s+$//; $_ }
            grep !/^#/ => split /\n/, $section;
        # Skip empty sections
        next if (keys %opts == 0) or (exists $opts{ "" } and keys %opts == 1);

        if (  grep m|^/.+/?$| => keys %opts ) { # Policy section
            my @targets;
            my @lines = keys %opts;
            foreach my $line ( @lines ) {
                next unless $line =~ m|^/(.+?)/?$|;

                push @targets, $1;
                delete $opts{ $line };
            }
            if ( @targets > 1 ) {
                require Carp;
                Carp::carp "Multiple policy lines in one section:\n\t",
                           join( "\n\t", @targets ),
                           "\nWill use /$targets[0]/\n";
            }
            push @{ $self->{_sections} }, 
                 { policy_target => $targets[0], 
                   args => [ sort {$opts{ $a } <=> $opts{ $b }} keys %opts ] };

        } else { # Buildopt section
            push @{ $self->{_sections} }, 
                 [ sort {$opts{ $a } <=> $opts{ $b}} keys %opts ];
        }
    }
    push @{ $self->{_sections} }, [ "" ] unless @{ $self->{_sections} };

    $self->{v} > 1 and printf "Left with %d parsed sections\n", 
                              scalar @{ $self->{_sections} };
    $self->_serialize;
    $self->{v} > 1 and printf "Found %d (unfiltered) configurations\n", 
                              scalar @{ $self->{_list} };
}

=item $self->_serialize( )

C<_serialize()> creates a list of B<Test::Smoke::BuildCFG::Config> 
objects from the parsed sections.

=cut

sub _serialize {
    my $self = shift;

    my $list = [ ];
    __build_list( $list, $self->{dfopts}, [ ], @{ $self->{_sections} } );

    $self->{_list} = $list;
}

=item __build_list( $list, $previous_args, $policy_subst, $this_cfg, @cfgs )

Recursive sub, mainly taken from the old C<run_tests()> in F<mktest.pl>

=cut

sub __build_list {
    my( $list, $previous_args, $policy_subst, $this_cfg, @cfgs ) = @_;

    my $policy_target;
    if ( ref $this_cfg eq "HASH" ) {
        $policy_target = $this_cfg->{policy_target};
        $this_cfg      = $this_cfg->{args};
    }

    foreach my $conf ( @$this_cfg ) {
        my $config_args = $previous_args;
        $config_args .= " $conf" if length $conf;

        my @substitutions = @$policy_subst;
        push @substitutions, [ $policy_target, $conf ] 
            if defined $policy_target;

        if ( @cfgs ) {
            __build_list( $list, $config_args, \@substitutions, @cfgs );
            next;
        }

        push @$list, Test::Smoke::BuildCFG::Config->new(
            $config_args, @substitutions
        );
    }
}

=item $buildcfg->configurations( )

Returns the list of configurations (Test::Smoke::BuildCFG::Config objects)

=cut

sub configurations {
    my $self = shift;

    @{ $self->{_list} };
}

=item Test::Smoke::BuildCFG->default_buildcfg()

This is a constant that returns a textversion of the default 
configuration.

=cut

sub default_buildcfg() {

    return <<__EOCONFIG__;

=

-Duseithreads
=
-Uuseperlio

-Duse64bitint
-Duselongdouble
-Dusemorebits
=
/-DDEBUGGING/

-DDEBUGGING
__EOCONFIG__
}

1;

=back

=cut

package Test::Smoke::BuildCFG::Config;

use overload
    '""'     => sub { $_[0]->[0] },
    fallback => 1;

use Text::ParseWords qw( quotewords );

=head1 PACKAGE

Test::Smoke::BuildCFG::Config - OO interface for a build confiuration

=head1 SYNOPSIS

    my $bcfg = Test::Smoke::BuildCFG::Config->new( $args, $policy );

or

    my $bcfg = Test::Smoke::BuildCFG::Config->new;
    $bcfg->args( $args );
    $bcfg->policy( [ -DDEBUGGING => '-DDEBUGGING' ], 
                   [ -DPERL_COPY_ON_WRITE => '' ] );

    if ( $bcfg->has_arg( '-Duseithreads' ) ) {
        # do stuff for -Duseithreads
    }

=head1 DESCRIPTION

This is a simple object that holds both the build arguments and the 
policy substitutions. The build arguments are stored as a string and
the policy subtitutions are stored as a list of lists. Each substitution is
represented as a list with the two elements: the target and its substitute.

=head1 METHODS

=over 4

=item Test::Smoke::BuildCFG::Config->new( [ $args[, \@policy_substs ]] )

Create the new object as an anonymous list.

=cut

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;

    my $self = bless [ undef, [ ], { } ], $class;

    @_ >= 1 and $self->args( shift );
    @_ >  0 and $self->policy( @_ );

    $self;
}

=item $buildcfg->args( [$args] )

Accessor for the build arguments field.

=cut

sub args {
    my $self = shift;

    if ( defined $_[0] ) {
        $self->[0] = shift;
        $self->_split_args;
    }

    $self->[0];
}

=item $buildcfg->policy( [@substitutes] )

Accessor for the policy substitutions.

=cut

sub policy {
    my $self = shift;

    if ( @_ ) {
        my @substitutions = @_ == 1 &&  ref $_[0][0] eq 'ARRAY' 
            ? @{ $_[0] } : @_;
        $self->[1] = \@substitutions;
    }

    @{ $self->[1] };
}

=item $self->_split_args( )

Create a hash with all the build arguments as keys.

=cut

sub _split_args {
    my $self = shift;

    $self->[2] = {
        map { ( $_ => 1 ) } quotewords( '\s+', 1, $self->[0] )
    };
}

=item $buildcfg->has_arg( $arg[,...] )

Check the build arguments hash for C<$arg>. If you specify more then one 
the results will be logically ANDed!

=cut

sub has_arg {
    my $self = shift;

    my $ok = 1;
    $ok &&= exists $self->[2]{ $_ } foreach @_;
    return $ok;
}

=item $buildcfg->any_arg( $arg[,...] )

Check the build arguments hash for C<$arg>. If you specify more then one 
the results will be logically ORed!

=cut

sub any_arg {
    my $self = shift;

    my $ok = 0;
    $ok ||= exists $self->[2]{ $_ } foreach @_;
    return $ok;
}

1;

=back

=head1 SEE ALSO

L<Test::Smoke::Smoker>, L<Test::Smoke::Syncer::Policy>

=head1 COPYRIGHT

(c) 2002-2003, All rights reserved.

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
