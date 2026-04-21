#!/usr/bin/perl

# Copyright (C) 2014 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package HTTP::Server::Connection;

use strict;
use warnings;

use HTTP::Message;

our (@ISA) = qw(Poslfit::Server::Connection);

use Poslfit::Server::Connection;

=pod

=head1 NAME

HTTP::Server::Connection - HTTP Server Connection Class

=head1 SYNOPSIS

  See HTTP::Server.
  
=head1 ABSTRACT

This Perl module implements a minimal client for HTTP::Server, and should
be subclassed to provide additional functionality.

=head1 DESCRIPTION

=over 4

=cut

sub initialise ($@) {
  my $this = shift;
  my (%param) = @_;

  $this->{'hsc_request'} = undef;

  for my $key (qw()) {
    my $internal_key = "hsc_$key";
    if (exists $param{$key}) { $this->{$internal_key} = $param{$key}; }
    elsif (!exists $this->{$key}) {
      die "Missing required parameter ($key).";
      }
    }
  }

sub new ($@) {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my (%options) = @_;
  my $this = $class->SUPER::new(%options);
  bless($this, $class);
  $this->initialise(@_);
  return $this;
  }

=item $sp->DeleteRequest();

Delete the HTTP request (if any) that has been received.

=cut

sub DeleteRequest ($) {
# warn "DeleteRequest " . join(',', (caller(0))[0..3]); # DEBUG
  my $this = shift;
  delete $this->{'hsc_request'}; 
  }

=item $req = $sp->GetRequest();

Return the HTTP request (if any) that has been received.

=cut

sub GetRequest($) {
  my $this = shift;
  return $this->{'hsc_request'};
  }

sub InputAvailable ($$) {
  my $this = shift;
  my $count = shift;

  if ($this->GetRequest()) {
    $this->Log("Data received after completed request");
    return;
    }

  $this->UpdateActivityTimestamp() if $count > 0;

  my $string_handle_buffer = $this->ReadAll();
  open my $string_handle, '+<', \$string_handle_buffer;
  my $request = new HTTP::Message('handle' => $string_handle);
  unless (defined $request) {
    $this->Log("fail Can't create request object");
    return;
    }
  if (my $error = $request->Error()) {
    $this->Log("part Can't part request yet: $error");
    if ($error =~ /^Incomplete/) {
      $this->Unread($string_handle_buffer);
      }
    }
  else {
#   warn "pars $cfn\n";
    $this->SetRequest($request);
    # ask multiserver to give us runtime to process the request
    $this->SetState('running'); 
    }
  }

sub Opened ($) {
  my $this = shift;

  $this->SUPER::Opened();
  $this->Log('peer '.$this->GetInputHandle()->peerhost());
  $this->GetMultiServer()->SetConnectionTimeout($this->GetID(), 60);
  }

=item $cp->Run();

Called by the multiserver when we have told it that we need runtime
to process a completely received HTTP request.

=cut

sub Run ($$) {
  my $this = shift;
  $this->SetState('idle'); 
  my $request = $this->GetRequest();
  $this->DeleteRequest();
  my $http_version = $request->HTTPVersion();
  my $host = $request->Header('host') || '';
  my $url = $request->URL();
  $this->Log("proc $host $url $http_version");
  my $sub = $this->GetServer()->GetHTTPServerContentHandler();
  my $response;
  eval { $response = &$sub($request, $this); };
  if ($@) {
    $response = new HTTP::Message();
    $response->StatusCode(500);
    $response->Body("<h1>Internal Server Error</h1><p>Content handler aborted: $@</p>");
    warn "500\t$url\t$@\n";
    }
  elsif ((!ref($response)) or !$response->isa('HTTP::Message')) {
    $response = new HTTP::Message();
    $response->StatusCode(500);
    $response->Body("Content handler did not return HTTP::Message");
#   warn "not a message\n";
    }
  # supply default values for mandatory data
  elsif (!defined $response->StatusCode()) { 
    $response->StatusCode(500); 
#   warn "no code\n";
    }
  if (!defined $response->Body()) { $response->Body(''); }
  if (!defined $response->Header('content-type')) { 
#   warn "setting to text/html: ".join(',', do { my $x = substr($response->Body(), 0, 100); $x =~ s/[\n\r]/\\n/g; $x }. %{$response->{'headers'}});
    $response->Header('content-type', 'text/html'); 
    }
  # redirections require a Location:
  if ($response->StatusCode() =~ /^3/ && 
    !defined $response->Header('location')) {
#   warn "no location\n";
    $response->StatusCode(500);
    $response->Body("Content handler did not specify Location:.");
    }
  if ($http_version !~ /^(?:0\.9|1\.0|1\.1)$/) { $http_version = '1.1'; }
  # HTTP/1.1 requires Host:
  if ($http_version eq '1.1' && !defined $request->Header('Host')) {
    $response->StatusCode(400);
    $response->Body("HTTP 1.1 request did not include Host:");
    }
  $response->HTTPVersion($http_version);
  # $this->WriteResponse($cfn, $response); # formerly this
  $response->Header('server', $this->GetServer()->GetHTTPServerVersion());
  $response->Date(time) unless $response->Header('date');
  $this->Write($response->ToString());
  my $connection_type = $request->Header('Connection') || '';
  if ($connection_type =~ /\bclose\b/ || $http_version ne '1.1') 
    { $this->SetCloseOnFlush(1); }
  }

=item $req = $sp->SetRequest($request);

Save a HTTP request that has been received.

=cut

sub SetRequest ($$) {
  my $this = shift;
  my $rp = shift;
  die unless defined $rp;
# warn $rp->ToString(); # DEBUG
# warn "SetRequest($rp) " . join(',', (caller(0))[0..3]); # DEBUG
  $this->{'hsc_request'} = $rp;
  }

sub Timeout ($) {
  my $this = shift;
  $this->GetOutputHandle()->print("500 Timeout\015\012\015\012");
  $this->GetMultiServer()->CloseConnection($this->GetID());
  }

1;
