#!/usr/bin/perl

# Copyright (C) 2014 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package Poslfit::Server::Connection;

use strict;
use warnings;

use Time::HiRes qw(time);

=pod

=head1 NAME

Poslfit::Server::Connection - Common code for connections to servers running under Poslfit::MultiServer

=head1 SYNOPSIS

  See Poslfit::MultiServer.

=head1 ABSTRACT

This Perl module implements common code for connections connected to
servers running under Poslfit::MultiServer.

=head1 DESCRIPTION

=over 4

=cut

sub new ($@) {
  my $proto = shift;
  my $class = ref($proto) || $proto;
# my $this = $class->SUPER::new();
  my (%options) = @_;
  my $this = {
    'pc_cid' => undef,
    'pc_close_on_flush' => 0,
    'pc_ibuf' => undef,
    'pc_ifh' => undef,
    'pc_multiserver' => undef,
    'pc_obuf' => undef,
    'pc_ofh' => undef,
    'pc_sid' => undef,
    'pc_state' => 'idle', # 'running' (if waiting for more CPU)
    'pc_time' => time,
    };
  # required parameters
  for my $key (qw(cid multiserver sid)) {
    my $internal_key = "pc_$key";
    if (exists $options{$key}) { $this->{$internal_key} = $options{$key}; }
    elsif (!exists $this->{$internal_key}) {
      die "Missing required parameter ($key).";
      }
    }
  # optional parameters
  for my $key (qw(ifh ofh)) {
    my $internal_key = "pc_$key";
    if (exists $options{$key}) { $this->{$internal_key} = $options{$key}; }
    }
  bless($this, $class);

  if (defined $this->GetInputHandle()) {
    $this->{'pc_ibuf'} = '';
    }
  if (defined $this->GetOutputHandle()) {
    $this->{'pc_obuf'} = '';
    }

  return $this;
  }

sub ClearOutputBuffer ($) {
  my $this = shift;
  $this->{'pc_obuf'} = '';
# $this->Log('cob'); # DEBUG
  $this->GetMultiServer()->WantOutput($this->GetID(), 0);
  }

sub Close ($) {
  my $this = shift;
  my $msp = $this->GetMultiServer();
  my $cid = $this->GetID();
  my $ifn = (defined $this->{'pc_ifh'}) ? $this->{'pc_ifh'}->fileno : undef;
  my $ofn = (defined $this->{'pc_ofh'}) ? $this->{'pc_ofh'}->fileno : undef;
  $this->Log('clos');
  if (defined $ifn) {
#   $this->Log('clos in 1'); # DEBUG
    if ((defined $ofn) && $ifn == $ofn) {
      $msp->WantOutput($cid, 0);
      $this->{'pc_ofh'} = undef;
      $this->{'pc_obuf'} = undef;
      $ofn = undef;
      }
    $msp->WantInput($cid, 0);
    $this->GetInputHandle()->close();
    $this->{'pc_ifh'} = undef;
    $this->{'pc_ibuf'} = undef;
#   $this->Log('clos in 2'); # DEBUG
    }
  if (defined $ofn) {
#   $this->Log('clos out'); # DEBUG
    $msp->WantOutput($cid, 0);
    $this->GetOutputHandle()->close();
    $this->{'pc_ofh'} = undef;
    $this->{'pc_obuf'} = undef;
    }
  }

=item $cp->Fill();

Called by Poslfit::MultiServer() when select(2) reports input
is available.  Connection should read as much data as possible
into its buffer, and begin processing it if possible.

Die if connection has no input handle.

Return undef on error.

Otherwise, return bytes (or Unicode characters on a UTF8 handle)
read, with the usual convention that 0 bytes are read on EOF.

=cut

sub Fill ($) {
  my $this = shift;
  die unless $this->GetInputHandle();
  my $buffer = '';
  my $count = $this->GetInputHandle()->sysread($buffer, 65536);
  if (!defined $count) {
    $this->Log("oops sysread failed: $!");
    return undef;
    }
# $this->Log("read $count"); # DEBUG
  return $count if $count == 0;
  $this->{'pc_ibuf'} .= $buffer;
  $this->InputAvailable($count);
  return $count;
  }

=item $still_open = $cp->Flush();

Try to send all buffered output to the connection's output handle.

Die if connection has no output handle.

Return -1 if connection closed as a result of close_on_flush 
condition being satisfied.

Otherwise, return number of bytes (or characters for a UTF8 
handle) remaning in buffer.

=cut

sub Flush ($) {
  my $this = shift;
  die "connection has no output handle" unless defined $this->GetOutputHandle();

  my $cid = $this->GetID();
  my $msp = $this->GetMultiServer();
  my $left = length($this->{'pc_obuf'});
  if ($left) {
    my $written = $this->GetOutputHandle()->syswrite($this->{'pc_obuf'});
    if (defined $written) {
#     $this->Log("obuf: $this->{'pc_obuf'}"); # DEBUG
      substr($this->{'pc_obuf'}, 0, $written) = '';
      $left = length($this->{'pc_obuf'});
#     $this->Log("dbug wrote $written, $left left"); # DEBUG
      }
    else {
      $this->Log("oops syswrite failed: $!");
      }
    }
  $msp->WantOutput($cid, $left > 0);
  if ($left == 0 && $this->{'pc_close_on_flush'}) {
    $msp->CloseConnection($cid);
    return -1;
    }
  return $left;
  }

sub GetActivityTimestamp ($) { my $this = shift; return $this->{'pc_time'}; }

sub GetConnection ($$) {
  my $this = shift;
  my $cid = shift;
  my $msp = $this->GetMultiServer();
  my $cp = $msp->GetConnection($cid);

  return undef if $cp->GetServerID() != $this->GetServerID();
  return $cp;
  }

sub GetID ($) { my $this = shift; return $this->{'pc_cid'}; }

sub GetInputHandle ($) { my $this = shift; return $this->{'pc_ifh'}; }

sub GetMultiServer ($) 
  { my $this = shift; return $this->{'pc_multiserver'}; }

sub GetOutputHandle ($) { my $this = shift; return $this->{'pc_ofh'}; }

sub GetServerID ($) { my $this = shift; return $this->{'pc_sid'}; }

sub GetServer ($) { 
  my $this = shift;
  return $this->GetMultiServer()->GetServer($this->GetServerID()); 
  }

sub GetState ($) { my $this = shift; return $this->{'pc_state'}; }

=item $cp->InputAvailable($count);

Called internally whenever new input data is available.
C<$count> gives the number of bytes (or Unicode characters
in UTF8 encoding) of data available. If not overridden,
calls the server's ConnectionInputAvailable if available.

=cut

sub InputAvailable ($$) {
  my $this = shift;
  my $count = shift;
  my $sp = $this->GetServer();
  if ($sp->can('ConnectionInputAvailable')) {
    $sp->ConnectionInputAvailable($this->GetID(), $count);
    }
  }

sub Log ($$) {
  my $this = shift;
  my $s = shift;
  $this->GetMultiServer()->ConnectionLog($this->GetID(), $s);
  }

=item $cp->Opened();

Called by Poslfit::MultiServer to give us a chance to register
our connection with it.

=cut

sub Opened ($) {
  my $this = shift;
  my $msp = $this->GetMultiServer();
  my $cid = $this->GetID();
  my @fn;
  if (my $ifh = $this->GetInputHandle()) {
    $msp->WantInput($cid, 1);
    push(@fn, $ifh->peerhost);
    push(@fn, '<' . $ifh->fileno);
    }
  if (my $ofh = $this->GetOutputHandle()) {
    $msp->WantOutput($cid, 0);
    push(@fn, '>' . $ofh->fileno);
    }
  my $sp = $this->GetServer();
  $this->Log(join(' ', 'conn',  'S'.$sp->GetID(), @fn));
  if ($sp->can('ConnectionOpened')) {
    $sp->ConnectionOpened($cid);
    }
  }

sub ReadAll ($) {
  my $this = shift;
  my $s = $this->{'pc_ibuf'};
  $this->{'pc_ibuf'} = '';
  return $s;
  }

sub ReadLine ($) { 
  my $this = shift;
  return undef unless defined $this->{'pc_ibuf'};
  $this->{'pc_ibuf'} =~ s/^([^\015\012]*)(?:\015\012?|\012)// and do {
#   $this->Log('rdln '.length($1).'/'.length($&)); # DEBUG
    return $1;
    };
  return undef;
  }

=item $cp->SetCloseOnFlush($boolean);

Specify whether or not the connection should close itself when its
output buffer is fully flushed (as would be the case, e.g., for
an HTTP/1.0 connection).

=cut

sub SetCloseOnFlush ($$$) {
  my $this = shift;
  my $cof = shift;
# $this->Log('cof'); # DEBUG
  $this->{'pc_close_on_flush'} = $cof;
  }

sub SetState ($$) {
  my $this = shift;
  my $state = shift;
  die "Bad value for \$state: '$state'" unless $state =~ /^(idle|running)$/;
  $this->{'pc_state'} = $state;
  }

sub Unread ($$) {
  my $this = shift;
  my $s = shift;

  $this->{'pc_ibuf'} = $s . $this->{'pc_ibuf'};
  }

=item $cp->UpdateActivityTimestamp();

Call whenever something has happened to the connection to mark it as
active, for the purposes of timeouts.

=cut

sub UpdateActivityTimestamp ($) {
  my $this = shift;

  $this->{'pc_time'} = time;
  }

sub Write ($$) {
  my $this = shift;
  my $s = shift;
  return 0 if (!defined $s) || length($s) == 0;
  die "Can't write to closed socket: $s" unless defined $this->GetOutputHandle();
  $this->{'pc_obuf'} .= $s;
# $this->Log('writ '.length($s)); # DEBUG
  $this->GetMultiServer()->WantOutput($this->GetID(), 1);
  return length($s);
  }

1;
