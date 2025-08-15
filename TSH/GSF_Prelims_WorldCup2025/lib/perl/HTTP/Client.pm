#!/usr/bin/perl

# Copyright (C) 2005 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package HTTP::Client;

=pod

=head1 NAME

HTTP::Client - HTTP client class

=head1 SYNOPSIS

  use HTTP::Client;
  use HTTP::Message;
  my $c = new HTTP::Client;
  my $m = new HTTP::Message(
    'method' => 'POST',
    'url' => '/cgi-bin/submit-rdata.pl',
    'http-version' => '1.1',
    'message-headers' => {
      'content-type' => 'multipart/form-data',
      'host' => 'localhost',
      },
    );
  $m->FormData({'password', 'frobozz'});
  $c->Connect("localhost") or die;
  $c->Send($m);
  my $r = $c->Receive();
  $c->Close();
  if (my $error = $r->Error()) {
    print "$error\n";
    }
  my $html = $r->Body();
  
=head1 ABSTRACT

This Perl module implements a HyperText Transfer Protocol client.

=head1 DESCRIPTION

=over 4

=cut

use strict;
use warnings;

use Fcntl qw(F_GETFL F_SETFL O_NONBLOCK);
use Socket;
use IO::Socket::INET;

use HTTP::Message;

sub new ($@);
sub Close ($);
sub Connect ($$);
sub Die ($$);
sub Receive($);
sub Send ($$);
sub SendRaw ($$);

=item $c = new HTTP::Client($key1 => $value1, ...);

Create a new HTTP::Client object.  
All parameter keys are optional.
C<exit_on_error> gives a boolean value specifying whether or not to
exit on any error.

=cut

sub new ($@) {
  my $proto = shift;
  my $class = ref($proto) || $proto;
# my $this = $class->SUPER::new();
  my $this = {
    'buffer' => '',
    'exit_on_error' => 1,
    'max_retry' => 20,
    'proto' => undef,
    'ssl_lib' => undef,
    'state' => 'init',
    };
  my %param = @_;
  for my $key (qw(exit_on_error ssl_lib)) {
    if (exists $param{$key}) { $this->{$key} = $param{$key}; }
    elsif (!exists $this->{$key}) {
      die "Missing required parameter ($key).";
      }
    }
  if ($this->{'ssl_lib'}) {
    eval "use $this->{'ssl_lib'}";
    $this->Die("Cannot load $this->{'ssl_lib'}: $@") if $@;
    }
  
  bless($this, $class);
  return $this;
  }

=item $success = $c->Close();

Closes the HTTP connection, which cannot be used again until it is
reopened.  
Fails only if the connection was not open to begin with.

=cut

sub Close ($) {
  my $this = shift;
  
  return undef if $this->{'state'} eq 'error';
# if ($this->{'state'} ne 'open') 
#   { $this->Die("Close: connection is not open"); return undef; }
  if ($this->{'proto'} eq 'https' && $this->{'socket'}) {
    if ($this->{'ssl_lib'} eq 'IO::Socket::SSL') {
      $this->{'socket'}->close(SSL_fast_shutdown => 1);
      $this->{'socket'} = undef;
      }
    else {
      $this->{'socket'}->close();
      $this->{'socket'} = undef;
      }
    }
  $this->{'state'} = 'init';
  return 1;
  }

=item $success = $c->Connect($hostname);

Opens a connection to the named host.

=cut

sub Connect ($$) {
  my $this = shift;
  my $hostname = shift;

  return undef if $this->{'state'} eq 'error';
  if ($this->{'state'} ne 'init') 
    { $this->Die("Connection is already open"); return undef; }

  my $retries_left = $this->{'max_retry'};
  until ($retries_left-- <= 0) {
    if ($this->{'socket'} = IO::Socket::INET->new(
      PeerAddr => $hostname,
      PeerPort => 'http(80)',
      Proto => 'tcp',
      Blocking => 1,
      )) {
      $this->{'state'} = 'open';
      $this->{'proto'} = 'http';
      return 1;
      }
    my $error = $!;
    if ($^O eq 'MSWin32' and $] < 5.010 and !$error) { # 5.008008 doesn't work, for sure
      $error = "ActivePerl version $] does not support blocking TCP sockets, please upgrade";
      }
    else {
      $error =~ s/^Invalid argument$/You may not be connected to the Internet - test your connection and try again./;
      $retries_left -= 4;
      $retries_left = 0 if $retries_left < 0;
      }
    $this->Warn("Could not create socket for web connection to $hostname ($error), looks serious, skipping extra retries, retrying ($retries_left left)");
    sleep 1;
    }
  $this->Die("Tried $this->{'max_retry'} times to create socket for web connection, giving up");
  }

=item $success = $c->ConnectSecure('PeerAddr' => $hostname, 'PeerPort' => 443);

Opens a secure connection to the named host.

=cut

sub ConnectSecure ($$) {
  my $this = shift;
  my (%options) = @_;

  return undef if $this->{'state'} eq 'error';
  if ($this->{'state'} ne 'init') 
    { $this->Die("Connection is already open"); return undef; }
  unless ($options{'PeerAddr'}) 
    { $this->Die("Missing required parameter: PeerAddr"); return undef; }
  $options{'PeerPort'} ||= 443;

  $this->SetupSSL() or return undef;

  my $retries_left = $this->{'max_retry'};
  until ($retries_left-- <= 0) {
    my $class = $this->{'ssl_lib'};
    if ($this->{'socket'} = $class->new(
      PeerAddr => $options{'PeerAddr'},
      PeerPort => $options{'PeerPort'},
      SSL_version => $options{'SSLVersion'} || 'TLSv1_2',
      )) {
      $this->{'state'} = 'open';
      $this->{'proto'} = 'https';
      return 1;
      }
    # will fail with $SSL_ERROR set to something like the following unless Net::SSLeay is installed
    # IO::Socket::INET6 configuration failed SSL structure creation failed error:140BA0C3:SSL routines:SSL_new:null ssl ctx
    our $SSL_ERROR;
    $this->Warn("Could not create socket for secure web connection ($!,$SSL_ERROR), retrying ($retries_left left)");
    if ($SSL_ERROR =~ /SSL structure/) {
      $this->Warn("This error likely means that you are trying to connect to a secure website without a necessary Perl library module.  If you are trying to use TSH to reach cross-tables.com, you likely need to install Net::SSLeay.");
      }
    sleep 1;
    }
  $this->Die("Tried $this->{'max_retry'} times to create socket for web connection, giving up");
  }

=item $c->Die($message);

Sets the module error message and exits if C<exit_on_error> was set.

=cut

sub Die ($$) { 
  my $this = shift;
  my $message = shift;
  $this->{'error'} = $message;
  $this->{'state'} = 'error';
  print STDERR "$message\n";
  exit 1 if $this->{'exit_on_error'};
  die $message;
  }

sub GetLine ($) {
  my $this = shift;
  return undef if $this->{'state'} eq 'error';
  if ($this->{'state'} ne 'open') 
    { $this->Die("GetLine: connection is not open"); return undef; }
  if ($this->{'proto'} eq 'http') {
    my $socket = $this->{'socket'};
    return scalar(<$socket>);
    }
  if ($this->{'proto'} eq 'https') {
    if ($this->{'ssl_lib'} eq 'IO::Socket::SSL') {
      my $socket = $this->{'socket'};
      return scalar(<$socket>);
      }
    # Net::SSL does not have working line buffering
    while ($this->{'buffer'} !~ /\015\012/) {
      print "Getting chunk.\n";
      $this->{'buffer'} .= $this->{'socket'}->getchunk();
      print "Got chunk, buffer length is " . length($this->{'buffer'}) . "\n";
      }
    if ($this->{'buffer'} =~ s/^(.*\015\012)//) {
      return $1;
      }
    $this->Die("Assertion 2 failed in GetLine"); 
    return undef;
    }
  $this->Die("Assertion 3 failed in GetLine"); 
  return undef;
  }

sub Read ($$$;$) {
  my $this = shift;
  return undef if $this->{'state'} eq 'error';
  if ($this->{'state'} ne 'open') 
    { $this->Die("Read: connection is not open"); return undef; }
  if ($this->{'proto'} eq 'http') {
    return read $this->{'socket'}, $_[0], $_[1], $_[2];
    }
  if ($this->{'proto'} eq 'https') {
    if ($this->{'ssl_lib'} eq 'Net::SSL') {
      die "offsets not yet supported" if $_[2];
      if ($_[1] <= length($this->{'buffer'})) {
	$_[0] = substr($this->{'buffer'}, 0, $_[1], '');
	return length($_[0]);
        }
      $_[0] = $this->{'buffer'};
      $this->{'buffer'} = '';
      my $rv = $this->{'socket'}->read($_[0], $_[1]-length($_[0]), length($_[0]));
      return $rv && length($_[0]);
      }
    return $this->{'socket'}->read($_[0], $_[1], $_[2]);
    }
  $this->Die("Assertion 1 failed in Read"); 
  return undef;
  }

=item $message = $c->Receive();

Reads an HTTP message (as a C<HTTP::Message>) from an open 
connection, returns undef or dies on failure.

=cut

sub Receive ($) {
  my $this = shift;

  return undef if $this->{'state'} eq 'error';
  if ($this->{'state'} ne 'open') 
    { $this->Die("Receive: connection is not open"); return undef; }

  return HTTP::Message->new('handle' => $this->{'socket'});
  }

=item $success = $c->Send($request);

Sends an HTTP message to the server.

=cut

sub Send ($$) {
  my $this = shift;
  my $request = shift;

  return undef if $this->{'state'} eq 'error';
  if ($this->{'state'} ne 'open') 
    { $this->Die("Send: connection is not open"); return undef; }

  my $s = $request->ToString();
# warn $s;
  $this->SendRaw($s);

  return 1;
  }

=item $success = $c->SendRaw($request);

Writes text to an open connection.

=cut

sub SendRaw ($$) {
  my $this = shift;
  my $request = shift;

  return undef if $this->{'state'} eq 'error';
  if ($this->{'state'} ne 'open') 
    { $this->Die("SendRaw: connection is not open"); return undef; }

  if ($this->{'proto'} eq 'https' && $this->{'ssl_lib'} eq 'Net::SSL') {
    $this->{'socket'}->print($request);
    return 1;
    }

  my $old = select($this->{'socket'});
  $| = 1;
  print $request;
  select $old;
# print "[begin request]\n$request\n[end request]\n";

  return 1;
  }

=item $success = $c->SetupSSL();

Make sure that an appropriate SSL library is loaded, returning boolean
success.

=cut

sub SetupSSL ($) {
  my $this = shift;
  return 1 if $this->{'ssl_lib'};
  if (defined &IO::Socket::SSL::new) {
    $this->{'ssl_lib'} = 'IO::Socket::SSL';
    return 1;
    }
  if (defined &Net::SSL::new) {
    $this->{'ssl_lib'} = 'Net::SSL';
    return 1;
    }
  eval "use IO::Socket::SSL";
  if (defined &IO::Socket::SSL::configure) {
    $this->{'ssl_lib'} = 'IO::Socket::SSL';
    return 1;
    }
  eval "use Net::SSL";
  if (defined &Net::SSL::new) {
    $this->{'ssl_lib'} = 'Net::SSL';
    return 1;
    }
  $this->Die("No Perl SSL library could be found. Please contact John Chew and tell him so, and give the exact operating system version that you are using.");
  return 0;
  }

=item $c->Warn($message);

Issues a warning message.

=cut

sub Warn ($$) { 
  my $this = shift;
  my $message = shift;
# $this->{'error'} = $message;
# $this->{'state'} = 'error';
  print STDERR "$message\n";
# exit 1 if $this->{'exit_on_error'};
  }

=back

=cut

1;
