package Test::Smoke::FTPClient;
use strict;

use Net::FTP;

use vars qw( $VERSION );
$VERSION = '0.001';

my %CONFIG = (
    df_fserver  => undef,
    df_fuser    => 'anonymous',
    df_fpasswd  => 'smokers@perl.org',
    df_v        => 0,
    df_fpassive => 1,

    valid      => [qw( fuser fpasswd fpassive )],
);

=head1 NAME

Test::Smoke::FTPClient - Implement a mirror like object

=head1 SYNOPSIS

    use Test::Smoke::FTPClient;

    my $server = 'ftp.linux.activestate.com';
    my $fc = Test::Smoke::FTPClient->new( $server );

    my $sdir = '/pub/staff/gsar/APC/perl-current';
    my $ddir = '~/perlsmoke/perl-current';
    my $cleanup = 1; # like --delete for rsync

    $fc->mirror( $sdir, $ddir, $cleanup );

    $fc->bye;

=head1 DESCRIPTION

This module was written specifically to fetch the perl source-tree
from the APC. It will not suffice as a general purpose mirror module!
It only distinguishes between files and directories and relies on the 
output of the C<< Net::FTP->dir >> method.

This solution is B<slow>, you'd better use B<rsync>!

=head1 METHODS

=over 4

=item Test::Smoke::FTPClient->new( $server[, %options] )


=cut

sub  new {
    my $proto = shift;
    my $class = ref $proto || $proto;

    my $server = shift;

    unless ( $server ) {
        require Carp;
        Carp::croak( "Usage: Test::Smoke::FTPClient->new( \$server )" );
    };

    my %args_raw = @_ ? UNIVERSAL::isa( $_[0], 'HASH' ) ? %{ $_[0] } : @_ : ();

    my %args = map {
        ( my $key = $_ ) =~ s/^-?(.+)$/lc $1/e;
        ( $key => $args_raw{ $_ } );
    } keys %args_raw;

    my %fields = map {
        my $value = exists $args{$_} ? $args{ $_ } : $CONFIG{ "df_$_" };
        ( $_ => $value )
    } ( v => @{ $CONFIG{ valid } } );
    $fields{fserver} = $server;

    return bless \%fields, $class;

}

=item $ftpclient->connect( )

Returns true for success after connecting and login.

=cut

sub connect {
    my $self = shift;

    $self->{v} and print "Connecting to '$self->{fserver}' ";
    $self->{client} = Net::FTP->new( $self->{fserver},
        Passive => $self->{fpassive},
    );
    unless ( $self->{client} ) {
        $self->{error} = $@;
        $self->{v} and print "NOT OK ($self->{error})\n";
        return;
    }
    $self->{v} and print "OK\n";

    $self->{v} and print "Authenticating ";
    unless ( $self->{client}->login( $self->{fuser}, $self->{fpwd} ) ) {
        $self->{error} = $@ || 
            "Could not login($self->{fuser}) on $self->{pserver}";
        $self->{v} and print "NOT OK ($self->{error})\n";
        return;
    }
    $self->{v} and print "OK\n";

    return 1;
}

=item $client->mirror( $sdir, $ddir )

Set-up the environment and call C<__do_mirror()>
=cut

sub mirror {
    my $self = shift;
    return unless UNIVERSAL::isa( $self->{client}, 'Net::FTP' );

    my( $fdir, $ddir, $cleanup ) = @_;
    my $cwd = cwd();
    # Get the local directory sorted
    mkpath( $ddir, $self->{v} ) unless -d $ddir;
    unless ( chdir $ddir ) {
        $self->{error} = "Cannot chdir($ddir): $!";
        return;
    }
    __do_mirror( $self->{client}, $fdir, $ddir, $self->{v}, $cleanup );
    chdir $cwd;
}

=item Test::Smoke::FTPClient->config( $key[, $value] )

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

=item __do_mirror( $ftp, $ftpdir, $localdir, $verbose, $cleanup )

Recursive sub to mirror a tree from an FTP server.

=cut

sub __do_mirror {
    my( $ftp, $ftpdir, $localdir, $verbose, $cleanup ) = @_;

    $ftp->cwd( $ftpdir );
    $verbose and printf "Entering %s\n", $ftp->pwd;

    my @list = map parse_dir_line( $_ ) => $ftp->dir;

    foreach my $entry ( sort { $a->{type} cmp $b->{type} ||
                               $a->{name} cmp $b->{name} } @list ) {
        
        if ( $entry->{type} eq 'd' ) {
            my $new_locald = File::Spec->catdir( $localdir, $entry->{name} );
            unless ( -d $new_locald ) {
                mkpath( $new_locald, $verbose, $entry->{mode} );
            }
            chdir $new_locald;
            __do_mirror( $ftp,$entry->{name},$new_locald,$verbose,$cleanup );
            $entry->{time} ||= $entry->{date};
            utime $entry->{time}, $entry->{time}, $new_locald;
            $ftp->cwd( '..' );
            chdir File::Spec->updir;
            $verbose and print "Leaving '$entry->{name}' [$new_locald]\n";
        } else {
            $entry->{time}  = $ftp->mdtm( $entry->{name} ); #slow down
            my $destname = File::Spec->catfile( $localdir, $entry->{name} );

            my $skip;
            if ( -e $destname ) {
                my( $l_size, $l_mode, $l_time ) = (stat $destname)[7, 2, 9];
                $l_mode &= 07777;
                $skip = ($l_size == $entry->{size}) && 
                        ($l_mode == $entry->{mode}) &&
		        ($l_time == $entry->{time});
            }
            unless ( $skip ) {
                unlink $destname;
                $verbose and print "Now trying to fetch $entry->{name}\n";
                my $dest = $ftp->get( $entry->{name}, $destname );
                chmod $entry->{mode}, $dest;
                utime $entry->{time}, $entry->{time}, $dest;
            } else { 
                $verbose && print "Skipping '$entry->{name}'\n";
            }
        }
    }
    if ( $cleanup ) {
        $verbose and print "Cleanup '$localdir'\n";
        my %ok_file = map { ( $_->{name} => $_->{type} ) } @list;
        local *DIR;
        if ( opendir DIR, '.' ) {
            foreach ( readdir DIR ) {
                if( -f ) {
                    unless (exists $ok_file{ $_ } && $ok_file{ $_ } eq 'f') {
                        print "Delete $_\n";
                        unlink $_;
                    }
                } elsif ( -d && ! /^..?\z/ ) {
                     unless (exists $ok_file{ $_ } && $ok_file{ $_ } eq 'd') {
                        rmtree( $_, 1 );
                    }
                }
            }
            closedir DIR;
        }
    }
}

=item __parse_line_from_dir( $line )

The C<dir> command in FTP gives a sort of C<ls -la> output,
parts of this output are used as remote file-info.

sub __parse_line_from_dir {
    local $_ = shift || $_;
    my @field = split;

    ( my $type = substr $field[0], 0, 1 ) =~ tr/-/f/;
    return {
        name => $field[-1],
        type => $type,
        mode => __get_mode_from_text( substr $field[0], 1 ),
        size => $field[4],
        time => 0, 
        date => __time_from_ls( @field[5, 6, 7] ),
    };
}

=item __get_mode_from_text( $tmode )

This takes the text representation of a file-mode (like 'rwxr--r--')
and return the numeric value.

=cut

sub __get_mode_from_text {
    my( $tmode ) = @_; # nine letter/dash

    $tmode =~ tr/rwx-/1110/;
    my $mode = 0;
    for ( my $i = 0; $i < 3; $i++ ) {
        $mode <<= 3;
        $mode  += ord(pack B3 => substr $tmode, $i*3, 3) >> 5;
    }

    return $mode;
}

=item __time_from_ls( $mname, $day, $time_or_year )

This takes the three date/time related columns from the C<ls -la> output
and returns a localtime-stamp.

=cut

sub __time_from_ls { 
    my( $mname, $day, $time_or_year ) = @_;

    my( $local_year, $local_month) = (localtime)[5, 4];
    $local_year += 1900;

    my $month = int( index('JanFebMarAprMayJunJulAugSepOctNovDec', $mname)/3 );

    my( $year, $time ) = $time_or_year =~ /:/
        ? $month > $local_month ? ( $local_year - 1, $time_or_year ) :
            ($local_year, $time_or_year) : ($time_or_year, '00:00' );

    my( $hour, $minutes ) = $time =~ /(\d+):(\d+)/;

    require Time::Local;
    return Time::Local::timelocal( 0, $minutes, $hour, $day, $month, $year );
}

1;

=back
