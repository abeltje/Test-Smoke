package Test::Smoke::Mailer;
use strict;

# $Id$
use vars qw( $VERSION $P5P $NOCC_RE);
$VERSION = '0.008';

use Test::Smoke::Util qw( parse_report_Config );

$P5P       = 'perl5-porters@perl.org';
$NOCC_RE   = ' (?:PASS\b|FAIL\(X\))';
my %CONFIG = (
    df_mailer        => 'Mail::Sendmail',
    df_ddir          => undef,
    df_v             => 0,
    df_to            => 'daily-build-reports@perl.org',
    df_from          => '',
    df_cc            => '',
    df_ccp5p_onfail  => 0,
    df_mserver       => 'localhost',

    df_mailbin       => 'mail',
    mail             => [qw( cc mailbin )],
    df_mailxbin      => 'mailx',
    mailx            => [qw( cc mailxbin )],
    df_sendmailbin   => 'sendmail',
    sendmail         => [qw( from cc sendmailbin )],
    'Mail::Sendmail' => [qw( from cc mserver )],
    'MIME::Lite'     => [qw( from cc mserver )],

    valid_mailer => { sendmail => 1, mail => 1, mailx => 1,
                      'Mail::Sendmail' => 1, 'MIME::Lite' => 1, },
);

=head1 NAME

Test::Smoke::Mailer - Wrapper to send the report.

=head1 SYNOPSIS

    use Test::Smoke::Mailer;

    my %args = ( mhowto => 'smtp', mserver => 'smtp.your.domain' );
    my $mailer = Test::Smoke::Mailer->new( $ddir, %args );

    $mailer->mail or die "Problem in mailing: " . $mailer->error;

=head1 DESCRIPTION

This little wrapper still allows you to use the B<sendmail>, 
B<mail> or B<mailx> programs, but prefers to use the B<Mail::Sendmail>
module (which comes with this distribution) to send the reports.

=head1 METHODS

=over 4

=item Test::Smoke::Mailer->new( $mailer[, %args] )

Can we provide sensible defaults for the mail stuff?

    mhowto  => [Module::Name|sendmail|mail|mailx]
    mserver => an SMTP server || localhost
    mbin    => the full path to the mail binary
    mto     => list of addresses (comma separated!)
    mfrom   => single address
    mcc     => list of addresses (coma separated!)

=cut

sub  new {
    my $proto = shift;
    my $class = ref $proto || $proto;

    my $mailer = shift || $CONFIG{df_mailer};

    unless ( exists $CONFIG{valid_mailer}->{ $mailer } ) {
        require Carp;
        Carp::croak( "Invalid mailer '$mailer'" );
    };

    my %args_raw = @_ ? UNIVERSAL::isa( $_[0], 'HASH' ) ? %{ $_[0] } : @_ : ();

    my %args = map {
        ( my $key = $_ ) =~ s/^-?(.+)$/lc $1/e;
        ( $key => $args_raw{ $_ } );
    } keys %args_raw;

    my %fields = map {
        my $value = exists $args{$_} ? $args{ $_ } : $CONFIG{ "df_$_" };
        ( $_ => $value )
    } ( v => ddir => to => ccp5p_onfail => @{ $CONFIG{ $mailer } } );
    $fields{ddir} = File::Spec->rel2abs( $fields{ddir} );

    DO_NEW: {
        local $_ = $mailer;

        /^sendmail$/  && return Test::Smoke::Mailer::Sendmail->new( %fields );
        /^mailx?$/ && return Test::Smoke::Mailer::Mail_X->new( %fields );
        /^Mail::Sendmail$/ && 
            return Test::Smoke::Mailer::Mail_Sendmail->new( %fields );
        /^MIME::Lite$/ && 
            return Test::Smoke::Mailer::MIME_Lite->new( %fields );
    }

}

=item $mailer->fetch_report( )

C<fetch_report()> reads B<mktest.rpt> from C<{ddir}> and return the
subject line for the mail-message.

=cut

sub fetch_report {
    my $self = shift;

    my $report_file = File::Spec->catfile( $self->{ddir}, 'mktest.rpt' );

    local *REPORT;
    if ( open REPORT, "< $report_file" ) {
        $self->{body} = do { local $/; <REPORT> };
        close REPORT;
    } else {
        require Carp;
        Carp::croak "Cannot read '$report_file': $!";
    }

    my @config = parse_report_Config( $self->{body} );

    return sprintf "Smoke [%s] %s %s %s %s (%s)", @config[0, 1, 5, 2, 3, 4];
}

=item $mailer->error( )

C<error()> returns the value of C<< $mailer->{error} >>.

=cut

sub error {
    my $self = shift;

    return $self->{error} || '';
}

=item $self->_get_cc( $subject )

C<_get_cc()> implements the C<--ccp5p_onfail> option. It looks at the
subject to see if the smoke FAILed and then adds the I<perl5-porters>
mailing-list to the C<Cc:> field unless it is already part of C<To:>
or C<Cc:>.

The new behaviour is to only return C<Cc:> on fail. This is determined
by the new global regex kept in C<< $Test::Smoke::Mailer::NOCC_RE >>.

=cut

sub _get_cc {
    my( $self, $subject ) = @_;
    return "" if $subject =~ m/$NOCC_RE/;

    return $self->{cc} || "" unless $self->{ccp5p_onfail};

    my $p5p = $Test::Smoke::Mailer::P5P or return $self->{cc};
    my @cc = $self->{cc} ? $self->{cc} : ();

    push @cc, $p5p unless $self->{to} =~ /\Q$p5p\E/ || 
                          $self->{cc} =~ /\Q$p5p\E/;
    return join ", ", @cc;
}

=item Test::Smoke::Mailer->config( $key[, $value] )

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

1;

=back

=head1 Test::Smoke::Mailer::Sendmail

This handles sending the message by piping it to the B<sendmail> program.

=over 4

=cut

package Test::Smoke::Mailer::Sendmail;

@Test::Smoke::Mailer::Sendmail::ISA = qw( Test::Smoke::Mailer );

=item Test::Smoke::Mailer::Sendmail->new( %args )

Keys for C<%args>:

  * ddir
  * sendmailbin
  * to
  * from
  * cc
  * v

=cut

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;

    return bless { @_ }, $class;
}

=item $mailer->mail( )

C<mail()> sets up a header and body and pipes them to the B<sendmail>
program.

=cut

sub mail {
    my $self = shift;

    my $subject   = $self->fetch_report();
    my $cc = $self->_get_cc( $subject );
    my $header = "To: $self->{to}\n";
    $header   .= "From: $self->{from}\n" 
        if exists $self->{from} && $self->{from};
    $header   .= "Cc: $cc\n" if $cc;
    $header   .= "Subject: $subject\n\n";

    $self->{v} > 1 and print "[$self->{sendmailbin} -i -t]\n";
    $self->{v} and print "Sending report to $self->{to} ";
    local *MAILER;
    if ( open MAILER, "| $self->{sendmailbin} -i -t " ) {
        print MAILER $header, $self->{body};
        close MAILER or
            $self->{error} = "Error in pipe to sendmail: $! (" . $?>>8 . ")";
    } else {
        $self->{error} = "Cannot fork ($self->{sendmailbin}): $!";
    }
    $self->{v} and print $self->{error} ? "not OK\n" : "OK\n";

    return ! $self->{error};
}

=back

=head1 Test::Smoke::Mailer::Mail_X

This handles sending the message with either the B<mail> or B<mailx> program.

=over 4

=cut

package Test::Smoke::Mailer::Mail_X;

@Test::Smoke::Mailer::Mail_X::ISA = qw( Test::Smoke::Mailer );

=item Test::Smoke::Mailer::Mail_X->new( %args )

Keys for C<%args>:

  * ddir
  * mailbin/mailxbin
  * to
  * cc
  * v

=cut

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;

    return bless { @_ }, $class;
}

=item $mailer->mail( )

C<mail()> sets up the commandline and body and pipes it to either the 
B<mail> or the B<mailx> program.

=cut

sub mail {
    my $self = shift;

    my $mailer = $self->{mailbin} || $self->{mailxbin};

    my $subject = $self->fetch_report();
    my $cc = $self->_get_cc( $subject );

    my $cmdline = qq|$mailer -s '$subject'|;
    $cmdline   .= qq| -c '$cc'| if $cc;
    $cmdline   .= qq| $self->{to}|;

    $self->{v} > 1 and print "[$cmdline]\n";
    $self->{v} and print "Sending report to $self->{to} ";
    local *MAILER;
    if ( open MAILER, "| $cmdline " ) {
        print MAILER $self->{body};
        close MAILER or 
            $self->{error} = "Error in pipe to '$mailer': $! (" . $?>>8 . ")";
    } else {
	$self->{error} = "Cannot fork '$mailer': $!";
    }
    $self->{v} and print $self->{error} ? "not OK\n" : "OK\n";

    return ! $self->{error};
}

=back

=head1 Test::Smoke::Mailer::Mail_Sendmail

This handles sending the message using the B<Mail::Sendmail> module.

=over 4

=cut

package Test::Smoke::Mailer::Mail_Sendmail;

@Test::Smoke::Mailer::Mail_Sendmail::ISA =  qw( Test::Smoke::Mailer );

=item Test::Smoke::Mailer::Mail_Sendmail->new( %args )

Keys for C<%args>:

  * ddir
  * mserver
  * to
  * from
  * cc
  * v

=cut

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;

    bless { @_ }, $class;
}

=item $mailer->mail( )

C<mail()> sets up the message to be send by B<Mail::Sendmail>.

=cut

sub mail {
    my $self = shift;

    eval { require Mail::Sendmail; };

    $self->{error} = $@ and return undef;

    my $subject = $self->fetch_report();
    my $cc = $self->_get_cc( $subject );

    my %message = (
        To      => $self->{to},
        Subject => $subject,
        Body    => $self->{body},
    );
    $message{cc}   = $cc if $cc;
    $message{from} = $self->{from} if $self->{from};
    $message{smtp} = $self->{mserver} if $self->{mserver};

    $self->{v} > 1 and print "[Mail::Sendmail]\n";
    $self->{v} and print "Sending report to $self->{to} ";

    Mail::Sendmail::sendmail( %message ) or
        $self->{error} = $Mail::Sendmail::error;

    $self->{v} and print $self->{error} ? "not OK\n" : "OK\n";

    return ! $self->{error};
}

=back

=head1 Test::Smoke::Mailer::MIME_Lite

This handles sending the message using the B<MIME::Lite> module.

=over 4

=cut

package Test::Smoke::Mailer::MIME_Lite;

@Test::Smoke::Mailer::MIME_Lite::ISA =  qw( Test::Smoke::Mailer );

=item Test::Smoke::Mailer::MIME_Lite->new( %args )

Keys for C<%args>:

  * ddir
  * mserver
  * to
  * from
  * cc
  * v

=cut

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;

    bless { @_ }, $class;
}

=item $mailer->mail( )

C<mail()> sets up the message to be send by B<MIME::Lite>.

=cut

sub mail {
    my $self = shift;

    eval { require MIME::Lite; };

    $self->{error} = $@ and return undef;

    my $subject = $self->fetch_report();
    my $cc = $self->_get_cc( $subject );

    my %message = (
        To      => $self->{to},
        Subject => $subject,
        Type    => "TEXT",
        Data    => $self->{body},
    );
    $message{Cc}   = $cc  if $cc;
    $message{From} = $self->{from} if $self->{from};
    MIME::Lite->send( smtp => $self->{mserver} ) if $self->{mserver};

    my $ml_msg = MIME::Lite->new( %message );

    $self->{v} > 1 and print "[MIME::Lite]\n";
    $self->{v} and print "Sending report to $self->{to} ";

    $ml_msg->send or $self->{error} = "Problem sending mail";

    $self->{v} and print $self->{error} ? "not OK\n" : "OK\n";

    return ! $self->{error};
}

=back

=head1 COPYRIGHT

(c) 2002-2003, All rights reserved.

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
