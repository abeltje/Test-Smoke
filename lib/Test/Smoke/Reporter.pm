package Test::Smoke::Reporter;
use strict;

# $Id$
use vars qw( $VERSION );
$VERSION = '0.001';

use Cwd;
use File::Spec;
require File::Path;

my %CONFIG = (
    df_ddir       => File::Spec->curdir,
    df_outfile    => 'mktest.out',

    df_locale     => undef,
    df_defaultenv => 0,

    df_v          => 0,
);

=head1 NAME

Test::Smoke::Reporter - OO interface for handling the testresults (mktest.out)

=head1 SYNOPSIS

    use Test::Smoke;
    use Test::Smoke::Reporter;

    my $reporter = Test::Smoke::BuildCFG->new( $conf );


=head1 DESCRIPTION

Handle the parsing of the F<mktest.out> file.

=head1 METHODS

=over 4

=cut

=item Test::Smoke::BuildCFG->new( %args )

[ Constructor | Public ]

Initialise a new object.

=cut

sub new {
    my $proto = shift;
    my $class = ref $proto ? ref $proto : $proto;

    my %args_raw = @_ ? UNIVERSAL::isa( $_[0], 'HASH' ) ? %{ $_[0] } : @_ : ();

    my %args = map {
        ( my $key = $_ ) =~ s/^-?(.+)$/lc $1/e;
        ( $key => $args_raw{ $_ } );
    } keys %args_raw;

    my %fields = map {
        my $value = exists $args{$_} ? $args{ $_ } : $CONFIG{ "df_$_" };
        ( $_ => $value )
    } keys %{ $class->config( 'all_defaults' ) };

    my $self = bless \%fields, $class;
    $self->read_parse(  );
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

=item $self->read_parse( [$result_file] )

C<read_parse()> reads the build configurations file and parses it.

=cut

sub read_parse {
    my $self = shift;

    my $result_file = @_ ? $_[0] : $self->{outfile} 
        ? File::Spec->catfile( $self->{ddir}, $self->{outfile} )
        : "";
    if ( $result_file ) {
        $self->_read( $result_file );
        $self->_parse;
    }
    return $self;
}

=item $self->_read( $nameorref )

C<_read()> is a private method that handles the reading.

=over 4

=item B<Reference to a SCALAR> smokeresults are in C<$$nameorref>

=item B<Reference to an ARRAY> smokeresults are in C<@$nameorref>

=item B<Reference to a GLOB> smokeresults are read from the filehandle

=item B<Other values> are taken as the filename for the smokeresults

=back

=cut

sub _read {
    my $self = shift;
    my( $nameorref ) = @_;
    $nameorref = '' unless defined $nameorref;

    my $vmsg = "";
    local *SMOKERSLT;
    if ( ref $nameorref eq 'SCALAR' ) {
        $self->{_outfile} = $$nameorref;
        $vmsg = "from internal content";
    } elsif ( ref $nameorref eq 'ARRAY' ) {
        $self->{_outfile} = join "", @$nameorref;
        $vmsg = "from internal content";
    } elsif ( ref $nameorref eq 'GLOB' ) {
	*SMOKERSLT = *$nameorref;
        $self->{_outfile} = do { local $/; <SMOKERSLT> };
        $vmsg = "from anonymous filehandle";
    } else {
        if ( $nameorref ) {
            if ( open SMOKERSLT, "< $nameorref" ) {
                $self->{_outfile} = do { local $/; <SMOKERSLT> };
                close SMOKERSLT;
                $vmsg = "from $nameorref";
            } else {
                require Carp;
                Carp::carp "Cannot read smokeresults ($nameorref): $!";
                $self->{_outfile} = undef;
                $vmsg = "did fail";
            }
        } else { # Allow intentional default_buildcfg()
            $self->{_outfile} = undef;
            $vmsg = "did fail";
        } 
    }
    $self->{v} and print "Reading smokeresult $vmsg\n";
}

=item $self->_parse( )

=cut

sub _parse {
    my $self = shift;
    $self->{_rpt} = { }; $self->{_cache} = { }; $self->{_mani} = [ ];
    return $self unless defined $self->{_outfile};

    my( %rpt, $cfgarg, $debug, $tstenv, $start );
    my @lines = reverse split /\n+/, $self->{_outfile};
    while ( defined( local $_ = pop @lines ) ) {
        m/^\s*$/ and next;
        m/^-+$/  and next;
        s/\s*$//;

        if ( my( $status, $time ) = /(Started|Stopped) smoke at (\d+)/ ) {
            if ( $status eq "Started" ) {
                $start = $time;
                $rpt{started} ||= $time;
            } else {
                $rpt{secs} += ($time - $start) if defined $start;
            }
            next;
        }

        if  ( my( $patch ) = /^\s*Smoking patch\s* (\d+\S*)/ ) {
            $rpt{patch} = $patch;
            next;
        }

        if ( /^MANIFEST / ) {
            push @{ $self->{_mani} }, $_;
            next;
        }

        if ( s/^\s*Configuration:\s*// ) {
            # You might need to do something here with 
            # the previous Configuration: $cfgarg
            s/-Dusedevel\s+//;
            s/\s*-des//;
            $debug = s/-DDEBUGGING\s*// ? "D" : "N";
            s/\s+$//;

            $cfgarg = $_ || " ";

            push @{ $rpt{cfglist} }, $_ unless $rpt{config}->{ $cfgarg }++;
            next;
        }

        if ( m/(?:PERLIO|TSTENV)\s*=\s*([-\w:.]+)/ ) {
            $tstenv = $1;
            $rpt{$cfgarg}->{$debug}{minitest} = "M"
                if $tstenv eq 'minitest';
            # Deal with harness output
            s/^(?:PERLIO|TSTENV)\s*=\s+[-\w:.]+(?: :crlf)?\s*//;
        }

        if ( m/^\s*All tests successful/ ) {
            $rpt{$cfgarg}->{$debug}{$tstenv} = 
                $rpt{$cfgarg}{$debug}{minitest} || "O";
            next;
        }

        if ( m/Inconsistent testresults/ ) {
            push @{ $rpt{$cfgarg}->{$debug}{$tstenv} }, $_;
        }

#        if ( /^Finished smoking \d+/ ) {
#            $rpt{config}{ $cfg } = $cnt;
#            $rpt{finished} = "Finished";
#            next;
#        }

        if ( my( $status, $mini ) =
             m/^\s*Unable\ to
               \ (?=([cbmt]))(?:build|configure|make|test)
               \ (anything\ but\ mini)?perl/x) {
            $mini and $status = uc $status; # M for no perl but miniperl
            $rpt{$cfgarg}->{$debug}{$tstenv} = $status;
            next;
        }

        if ( m/FAILED/ || m/DIED/) {
            ref $rpt{$cfgarg}->{$debug}{$tstenv} or
                $rpt{$cfgarg}->{$debug}{$tstenv} = [ ];
            push @{ $rpt{$cfgarg}->{$debug}{$tstenv} }, $_;
            next;
        }
        if ( /^\s+\d+(?:[-\s]+\d+)*/ ) {
            push @{ $rpt{$cfgarg}->{$debug}{$tstenv}}, $_;
            next;
        }
        next;
    }

    $self->{_rpt} = \%rpt;
}

=item $self->_post_process( )

C<_post_process()> sets up the report for easy printing. It needs to
sort the buildenvironments.

=cut

sub _post_process {
    my $self = shift;
    my %bldenv;
    my $rpt = $self->{_rpt};
    foreach my $config ( @{ $rpt->{cfglist} } ) {
        foreach my $buildenv ( keys %{ $rpt->{ $config }{N} } ) {
            $bldenv{ $buildenv }++;
        }
        foreach my $buildenv ( keys %{ $rpt->{ $config }{D} } ) {
            $bldenv{ $buildenv }++;
        }
    }
}

1;

=back

=head1 SEE ALSO

L<Test::Smoke::Smoker>

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
