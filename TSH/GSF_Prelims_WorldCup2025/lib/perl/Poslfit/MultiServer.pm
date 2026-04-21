#!/usr/bin/perl

# Copyright (C) 2014 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package Poslfit::MultiServer;

use strict;
use warnings;

use Time::HiRes qw(time);

=pod

=head1 NAME

Poslfit::MultiServer - Module for operating one or more servers.

=head1 SYNOPSIS

  package Main;
  use Poslfit::MultiServer;
  use MyServer1;
  use MyServer2;
  
  my $msp = new Poslfit::MultiServer();
  my $sp1 = new MyServer1('multiserver' => $msp, ...);
  my $sp2 = new MyServer1('multiserver' => $msp, ...);

  $msp->Start();
  while ($msp->Run()) { }
  $msp->Stop();

  $msp->UnregisterServer($sp2->GetID());
  $msp->UnregisterServer($sp1->GetID());

  package MyServer1;

  use Poslfit::Server;

  our (@ISA) = 'Poslfit::Server';

  sub new ($@) {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my (%options) = @_;
    $options{'connection_class'} ||= 'MyConnection';
    my $this = $class->SUPER::new(%options);
    bless($this, $class);
    return $this;
    }

  sub ServerName ($) { my $this = shift; return 'My Server #1'; }

  sub Start ($) { 
    my $this = shift;
    if ('I run a listener port') {
      $this->SetHandle(IO::Socket::INET->new(
	Proto => 'tcp',
	Listen => SOMAXCONN, # use IO::Socket;
	LocalPort => $port,
	Reuse => 1,
	)) or die "bind failed: $!";
      }
    else { # manually adding connections another way
      $this->RegisterConnection('input' => *STDIN);
      $this->RegisterConnection('output' => *STDOUT);
      }
    $this->Log('Server started');
    }

  sub Stop ($) { 
    my $this = shift;
    $this->SUPER::Stop();
    $this->Log('Server stopped');
    }

  1;

  package MyConnection;

  use Poslfit::Server::Connection;

  our (@ISA) = 'Poslfit::Server::Connection';

  sub new ($@) {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my (%options) = @_;
    my $this = $class->SUPER::new(%options);
    bless($this, $class);
    return $this;
    }

  sub InputAvailable ($$) {
    my $cp = shift;
    my $count = shift;
    die "need to handle $count bytes/chars of input";
    }

  1;

=head1 ABSTRACT

This Perl module implements a multiple server architecture 
for sharing a common select(2) call among an arbitrary
number of servers running arbitrary protocols.

=head1 DESCRIPTION

=over 4

=cut

=item $server = new HTTP::MultiServer($key1 => $value1, ...);

Create a new HTTP::MultiServer object.  
All keys are optional.

=cut

sub new ($@) {
  my $proto = shift;
  my $class = ref($proto) || $proto;
# my $this = $class->SUPER::new();
  my (%options) = @_;
  my $this = {
    'connections' => {}, # map integer connection ID to Poslfit::Connection object
    'event_queue' => undef,
    'exiting' => 0, # set when trying to exit after flushing output
    'log_handle' => *STDERR,
    'next_cid' => 1, # next connection ID to assign
    'select_mask' => {
      'input' => '',
      'output' => '',
      'error' => '',
      },
    'servers' => [], # map integer server ID to Poslfit::Server object
    'timeouts' => {}, # map integer connection ID to timeout periods in seconds
    };
  bless($this, $class);
  # optional parameters
  for my $key (qw(event_queue log_handle select_timeout)) {
    if (exists $options{$key}) { $this->{$key} = $options{$key}; }
    }
  $this->Log('=====');
  return $this;
  }

=item $server->ConnectionLog($cid, $message);

Attribute a new log entry to a connection's server.

=cut

sub ConnectionLog ($$$) {
  my $this = shift;
  my $cid = shift;
  my $message = shift;

  my $sp = $this->GetConnectionServer($cid);
  ($sp || $this)->Log("C$cid $message");
  }

=item $msp->CloseConnection($cid);

Closes a specified connection.

=cut

sub CloseConnection ($$) {
  my $this = shift;
  my $cid = shift;
  my $cp = $this->GetConnection($cid);
  return unless defined $cp;
  my $sp = $this->GetConnectionServer($cid);
  $sp->ClosingConnection($cid);
  $cp->Close();
  delete $this->{'connections'}{$cid};
  delete $this->{'timeouts'}{$cid};
  $sp->ClosedConnection($cid);
# $this->Log('clos con 1'); # DEBUG
  }

=item $server->Die("message");

Called internally to log a fatal error before dying.

=cut

sub Die ($$) {
  my $this = shift;
  my $message = shift;
  $this->Log("Die: $message");
  die $message;
  }

=item $server->ForeachConnection($sub, $data);

For each connection belonging to this multiserver, 
call C<&$sub($connection, $data)>.

=cut

sub ForeachConnection ($$$) {
  my $this = shift;
  my $sub = shift;
  my $data = shift;

  while (my (undef, $cp) = each %{$this->{connections}}) { &$sub($cp, $data); }
  }

=item $ch = $server->GetConnection($cid);

Map connection ID to connection reference.

=cut

sub GetConnection ($$) {
  my $this = shift;
  my $cid = shift;

  return $this->{'connections'}{$cid};
  }

=item $sop = $msp->GetConnectionServer($cid);

Map connection file number to owner server object.

=cut

sub GetConnectionServer ($$) {
  my $this = shift;
  my $cid = shift;

  return $this->GetServer($this->GetConnection($cid)->GetServerID());
  }

=item $seconds = $msp->GetConnectionTimeout($cid);

Return the current value of the specified connection's timeout.
See C<SetConnectionTimeout> for more details.

=cut

sub GetConnectionTimeout ($$) {
  my $this = shift;
  my $cid = shift;

  return $this->{timeouts}{$cid};
  }

=item $sop = $msp->GetServer($sid);

Map server ID to server reference.

=cut

sub GetServer ($$) {
  my $this = shift;
  my $sid = shift;

  return $this->{'servers'}[$sid];
  }

=item (@sops) = $msp->GetServers();

Return a list of references to active server objects.

=cut

sub GetServers ($) {
  my $this = shift;

  return grep { defined $_ } @{$this->{'servers'}};
  }

=item $server->Log($message);

Called internally to log a message with a timestamp.

=cut

sub Log ($$) {
  my $this = shift;
  my $message = shift;
  my (@now) = gmtime;
  my $logfh = $this->{'log_handle'};
  printf $logfh "%04d%02d%02d %02d%02d%02d %s\n",
    $now[5]+1900, $now[4]+1, $now[3], $now[2], $now[1], $now[0],
    $message;
  }

=item $msp->RegisterConnection('input' => $handle, 'output' => $handle, 'sid' => $server_id);

Register a connection manually, used by TSH::Server::Console.

=cut

sub RegisterConnection ($$) {
  my $this = shift;
  my (%options) = @_;

  my $sid = $options{'sid'};
  die "sid not specified for RegisterConnection" unless defined $sid;
  my $sp = $this->GetServer($sid);
  my $cid = $this->{'next_cid'};
  my $found = 0;
  if ($cid >= 1<<30) {
    for my $i (1..$cid) {
      next if exists $this->{'connections'}{$i};
      $found = 1;
      $cid = $i;
      }
    }
  $this->{'next_cid'}++ unless $found;
# $this->Log("registered conn $cid on server $sid"); # DEBUG
  my $class = $options{'class'};
  my $cp = $this->{'connections'}{$cid} = $class->new(
    'ifh' => $options{'input'},
    'ofh' => $options{'output'},
    'cid' => $cid,
    'sid' => $sid,
    'multiserver' => $this,
    );
  my %attributes;
  $cp->Opened(\%attributes);
  }

=item $msp->RegisterServer($server);

Register a Poslfit::Server object with us.  Don't register the same
server twice, please.

=cut

sub RegisterServer($$) {
  my $this = shift;
  my $sp = shift;
  my $ssp = $this->{'servers'};
  for my $si (0..$#$ssp) {
    next if defined $si;
    $ssp->[$si] = $sp;
    return $si;
    }
  push(@$ssp, $sp);
  return $#$ssp;
  }

=item while ($server->Run()) { }

Checks to see if an HTTP request has been received.
If one has, it is processed.

=cut

sub Run ($) {
  my $this = shift;
  my $nports;
  my ($inp, $out, $err);

# print "listening ($this->{'exiting'})\n";
  my $timeout = $this->{'select_timeout'} || 1;
  {
    my $now = time;
    while (my ($cid, $seconds) = each %{$this->{'timeouts'}}) {
      my $aTimeout = $this->GetConnection($cid)->GetActivityTimestamp() +
        $seconds - $now;
      if ($timeout > $aTimeout) {
	$timeout = $aTimeout;
#	warn "timeout reduced to $timeout for conn #$cid";
	}
      }
  }
  my $busy = 0;
  my $was_exiting = $this->{'exiting'};
  my $event_queue = $this->{'event_queue'};
  $inp = $this->{'select_mask'}{'input'};
  $inp = '' if $this->{'exiting'};
  $nports = select(
    $inp,
    ($out = $this->{'select_mask'}{'output'}),
    ($err = $this->{'select_mask'}{'error'}),
    $timeout,
    );
# printf { $this->{'log_handle'} }  "nports=$nports inp=%s out=%s err=%s\n", unpack('b*', $inp), unpack('b*', $out), unpack('b*', $err);
  if ($nports < 0) { 
    if ($! =~ /Interrupted/) { $nports = 0; } # don't die on signals
    else {
      $this->Log("select() failed: $!");
      return 0; 
      }
    }
  if (my $event = $event_queue && $event_queue->dequeue_nb()) {
    if ($event eq 'shutdown') {
      print "Shutdown event received by server.\n";
      return 0;
      }
    else {
      $this->Die("Unknown event: $event");
      }
    }
  my (@servers) = $this->GetServers();
  if ($nports > 0) { # select() did not time out
  # $this->Log("$nports port(s) to check"); # DEBUG
    # check for new connections
    for my $sp (@servers) {
      my $sh = $sp->GetHandle() ||  next;
      my $sfn = $sh->fileno;
      if (vec($inp, $sfn, 1)) {
  #     $this->Log("port: accepting on server @{[$sp->GetID()]}"); # DEBUG
	$sp->Accept();
	vec($inp, $sfn, 1) = 0;
	$nports--;
	}
      }
    # check for activity on old connections
    if ($nports > 0) { #   warn "looking for I/O.\n";
      while (my ($cid, $cp) = each %{$this->{'connections'}}) {
  #     $this->Log("checking port $cid"); # DEBUG
	my $ifh = $cp->GetInputHandle();
	my $ofh = $cp->GetOutputHandle();
	my $input_available = $ifh && vec($inp, $ifh->fileno, 1);
	if ($ofh && vec($out, $ofh->fileno, 1)) {
	  vec($out, $ofh->fileno, 1) = 0;
	  $busy++;
	  my $left = $cp->Flush();
  #       $this->Log("port: $left bytes left to send $cid"); # DEBUG
	  last unless --$nports;
	  if ($left < 0) { # close-on-flush closed connection
	    $input_available = 0;
	    $nports--;
	    }
	  }
	if ($input_available) {
	  vec($out, $ifh->fileno, 1) = 0;
	  $cp->Fill() or $this->CloseConnection($cid);
  #       $this->Log("port: received data on $cid"); # DEBUG
	  last unless --$nports;
	  }
	}
      $this->Log("unknown activity: I".unpack('b*', $inp).'/O'.unpack('b*',$out)) unless $nports <= 0;
      }
    }

  # check to see if single-threaded connections wanted some runtime
  for my $cp (values %{$this->{'connections'}}) {
    $cp->Run() if $cp->GetState() eq 'running';
    }
  # check for connection timeouts
  my $now = time;
  while (my ($cid, $seconds) = each %{$this->{'timeouts'}}) {
    my $cp = $this->GetConnection($cid);
    if ($cp->GetActivityTimestamp() + $seconds <= $now) {
      $cp->Timeout();
      }
    }

  # TODO: document why we need to check was_exiting

  # warn "$busy $was_exiting $this->{'exiting'}";
  return $busy || (!$was_exiting) || (!$this->{'exiting'}) || @servers > 0;
  }

=item $msp->SetConnectionTimeout($cid, $seconds);

Ask multiserver to call the specified connection's Timeout method
(say to close the connection) if inactive (as measured by use of
UpdateInactivityTimestamp) for a specified number of seconds. 
To cancel a timeout, set C<$seconds> to 0.

=cut

sub SetConnectionTimeout ($$$) {
  my $this = shift;
  my $cid = shift;
  my $seconds = shift;
  die unless defined $seconds;

  if ($seconds) { $this->{'timeouts'}{$cid} = $seconds; }
  else { delete $this->{'timeouts'}{$cid}; }
  }

=item $msp->Start() or die;

Prepares the multiserver to accept new connections. 
Returns boolean indicating success.

=cut

sub Start ($) {
  my $this = shift;
  for my $sp ($this->GetServers()) {
    $sp->Start();
    my $sh = $sp->GetHandle() || next;
    # some old systems hang on accept() if a connecting connection drops
    # a half-open connection, so don't ever block
    $sh->blocking(0);
    my $sfn = $sh->fileno;
    # update the select(2) mask
    vec($this->{'select_mask'}{'input'}, $sfn, 1) = 1;
    }
  return 1;
  }

=item $server->Shutdown();

Tell the server to shut down the next time it returns from Run().

=cut

sub Shutdown ($) {
  my $this = shift;
  $this->{'exiting'} = 1;
  }

=item $msp->Stop();

Stops all servers running under the multiserver.

=cut

sub Stop ($) {
  my $this = shift;
  for my $sp ($this->GetServers()) {
    $this->StopServer($sp->GetID());
    }
  }

=item $msp->Stop($sid);

Stop one server running under the multiserver.

=cut

sub StopServer ($$) {
  my $this = shift;
  my $sid = shift;
  my $sp = $this->GetServer($sid);
  if (my $sh = $sp->GetHandle()) {
    vec($this->{'select_mask'}{'input'}, fileno($sh), 1) = 0;
    }
  $sp->Stop();
  while (my ($cid, $cp) = each %{$this->{'connections'}}) {
    next unless $cp->GetServerID() == $sid;
    $this->CloseConnection($cid);
    }
  }

=item $msp->UnregisterServer($sid);

Unregister a Poslfit::Server object.

=cut

sub UnregisterServer($$) {
  my $this = shift;
  my $sid = shift;
  $this->{'servers'}[$sid] = undef;
  }

=item $msp->WantInput($cid, $boolean);

Instruct the server to expect (or not, depending on C<$boolean>)
input for connection C<$cid>.

=cut

sub WantInput ($$$) {
  my $this = shift;
  my $cid = shift;
  my $boolean = shift;
  my $ifn = $this->GetConnection($cid)->GetInputHandle()->fileno;

  vec($this->{'select_mask'}{'input'}, $ifn, 1) = $boolean;
  }

=item $msp->WantOutput($cid, $boolean);

Instruct the server to send (or not, depending on C<$boolean>)
buffered output for connection C<$cid>.

=cut

sub WantOutput ($$$) {
  my $this = shift;
  my $cid = shift;
  my $boolean = shift;
  my $ofn = $this->GetConnection($cid)->GetOutputHandle()->fileno;
# $this->ConnectionLog($cid, "WntO $ofn $boolean"); # DEBUG
  die unless defined $ofn;

  vec($this->{'select_mask'}{'output'}, $ofn, 1) = $boolean;
  }

=back

=cut

1;
