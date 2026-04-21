#!/usr/bin/perl

# Copyright (C) 2014 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package Poslfit::Server;

use strict;
use warnings;

=pod

=head1 NAME

Poslfit::Server - Common code for servers running under Poslfit::MultiServer

=head1 SYNOPSIS

  package MyServer;

  our (@ISA) = Poslfit::Server;

  sub new ($@) {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my (%options) = @_;
    my $this = $class->SUPER::new(%options);
    bless($this, $class);
    return $this;
    }

  $this->Log('warning message');
  $this->Die('reason for dying');
  $h = $this->GetHandle(); # listener handle

  sub Start ($) { 
    my $this = shift;
    # one way
    if (1) {
      $this->RegisterConnection('input' => *STDIN); # See Poslfit::MultiServer
      return undef;
      }
    # another way
    else {
      my $handle = IO::Socket::INET->new(
	Proto => 'tcp',
	Listen => SOMAXCONN,
	LocalPort => $port,
	Reuse => 1,
	) or die "bind failed: $!";
      $this->SetHandle($handle);
      return $handle;
      }
    }

  sub Stop ($) {
    my $this = shift;
    $this->SUPER::Stop(); # closes handle, if any
    }

=head1 ABSTRACT

This Perl module implements common code for individual servers
running under Poslfit::MultiServer.

=head1 DESCRIPTION

=over 4

=cut

=item $server = new Poslfit::Server($key1 => $value1, ...);

Create a new Poslfit::Server object.  

Required options:

connection_class - Perl class for connections to the server

multiserver - reference to controlling Poslfit::MultiServer object

=cut

sub new ($@) {
  my $proto = shift;
  my $class = ref($proto) || $proto;
# my $this = $class->SUPER::new();
  my (%options) = @_;
  my $this = {
    };
  # required parameters
  for my $key (qw(connection_class multiserver)) {
    my $internal_key = "ps_$key";
    if (exists $options{$key}) { $this->{$internal_key} = $options{$key}; }
    elsif (!exists $this->{$internal_key}) {
      die "Missing required parameter ($key).";
      }
    }
  bless($this, $class);
  $this->{'ps_sid'} = $this->{'ps_multiserver'}->RegisterServer($this);
  eval "use $this->{'ps_connection_class'}";
  $this->Die("Cannot load class $this->{'ps_connection_class'}: $@") if $@;
  return $this;
  }

sub Accept ($) {
  my $this = shift;
  my $cfh = $this->{'ps_handle'}->accept();
  $cfh->autoflush(1);
  $cfh->blocking(0);
  $this->{'ps_multiserver'}->RegisterConnection('input' => $cfh,
    'output' => $cfh, 'sid' => $this->{'ps_sid'}, 
    'class' => $this->{'ps_connection_class'});
  }

sub ClosedConnection ($$) {
  my $this = shift;
  my $cid = shift;
  }

sub ClosingConnection ($$) {
  my $this = shift;
  my $cid = shift;

  $this->{'ps_multiserver'}->ConnectionLog($cid, 'disc');
  }

sub Die ($$) {
  my $this = shift;
  my $message = shift;
  $this->{'ps_multiserver'}->Die('['.$this->ServerName().'] '.$message);
  }

sub FECHelper ($$) {
  my $cp = shift;
  my $data2 = shift;
  my $sub = $data2->{sub};

  &$sub($cp, $data2->{data}) if $cp->GetServerID() == $data2->{id};
  }

=item $server->ForeachConnection($sub, $data);

For each connection belonging to this server, 
call C<&$sub($connection, $data)>.

=cut

sub ForeachConnection ($$$) {
  my $this = shift;
  my $sub = shift;
  my $data = shift;

  $this->{ps_multiserver}->ForeachConnection(\&FECHelper,
    { 'data' => $data, 'id' => $this->{ps_sid}, 'sub' => $sub });
  }

sub GetHandle ($) { my $this = shift; return $this->{'ps_handle'}; }

sub GetMultiServer ($) 
  { my $this = shift; return $this->{'ps_multiserver'}; }

sub GetID ($$) { my $this = shift; return $this->{'ps_sid'}; }

sub Log ($$) {
  my $this = shift;
  my $message = shift;
  $this->{'ps_multiserver'}->Log('['.$this->ServerName().'] '.$message);
  }

sub ReadConnectionLine ($$) {
  my $this = shift;
  my $cid = shift;
  return $this->{'ps_multiserver'}->GetConnection($cid)->ReadLine();
  }

sub RegisterConnection ($@) {
  my $this = shift;
  my (%options) = @_;
  $options{'class'} ||= $this->{'ps_connection_class'};
  $options{'sid'} = $this->{'ps_sid'};
  $this->{'ps_multiserver'}->RegisterConnection(%options);
  }

sub SetHandle ($$) { my $this = shift; $this->{'ps_handle'} = shift; }

=item $sp->Start();

Do everything necessary to get the server running.  

For example, call IO::Socket::INET->new() and store the handle, or
call RegisterConnection with fixed connections.

=cut

sub Start ($) {
  my $this = shift;
  die "Poslfit::Server::Start must be overridden";
  }

sub Stop ($) {
  my $this = shift;
  if (my $h = $this->GetHandle()) {
    $h->close();
    }
  }

=item $server->WriteConnection($cid, $s);

Writes $s to the connection identified by $cid.

=cut

sub WriteConnection ($$$) {
  my $this = shift;
  my $cid = shift;
  my $s = shift;
  $this->{'ps_multiserver'}->GetConnection($cid)->Write($s);
  }

=back

=cut

1;

