#!/usr/bin/perl

# Copyright (C) 2006-2014 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package HTTP::Server;

use strict;
use warnings;

use HTTP::Server::Connection;
use IO::Socket::INET qw( SOCK_STREAM SOMAXCONN );
use Poslfit::Server;

our (@ISA) = qw(Poslfit::Server);

=pod

=head1 NAME

HTTP::Server - HTTP Server Class

=head1 SYNOPSIS

  use Poslfit::MultiServer;
  use HTTP::Server;

  my $msp = new Poslfit::MultiServer();
  my $sp = new HTTP::Server(
    port => 7777,
    connection_class => 'SubclassOf_HTTP::Server::Connection',
    multiserver => $msp,
    ) or die;
  $msp->Start();
  while ($msp->Run()) {}
  $msp->Stop();
  
=head1 ABSTRACT

This Perl module implements a minimal HTTP server.

=head1 DESCRIPTION

=over 4

=cut

sub initialise ($@);
sub new ($@);
sub Run ($);
sub Start ($);
sub StaticContent ($$;$);

=item $server->initialise(%options);

Used initially by &new to initialise the object.  Options are
the same as for &new.

=cut

sub initialise ($@) {
  my $this = shift;
  my (%options) = @_;

  # code ref returning web content
  $this->{'hs_content'} = sub { new HTTP::Message('status-code' => '500',
    'body' => "No content handler configured") };
  # TCP/IP port for server
  # $this->{'hs_port'} = undef# must be in %options
  # server version in human-readable form
  # $this->{'hs_version'} = undef# must be in %options

 # required parameters
  for my $key (qw(port version)) {
    my $internal_key = "hs_$key";
    if (exists $options{$key}) { $this->{$internal_key} = $options{$key}; }
    elsif (!exists $this->{$key}) {
      die "Missing required parameter ($key).";
      }
    }
  # optional parameters
  for my $key (qw(content)) {
    if (exists $options{$key}) { $this->{$key} = $options{$key}; }
    }
  }

=item $server = new HTTP::Server({$key1 => $value1, ...});

Create a new HTTP::Server object.  
All options are required unless otherwise indicated.

C<connection_class>: Perl class for connection objects (default: HTTP::Server::Connection)

C<port>: port to listen on for new connections, defaults to 7777

C<version>: version number of this HTTP server, for reporting to clients

=cut

sub new ($@) {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my (%options) = @_;
  $options{'connection_class'} ||= 'HTTP::Server::Connection';
  my $this = $class->SUPER::new(%options);
  bless($this, $class);
  $this->initialise(@_);
  $this->Log("Object created");
  return $this;
  }

=item $sub = $sp->GetHTTPServerContentHandler();

Return the code reference that generates content for the HTTP server.

=cut

sub GetHTTPServerContentHandler ($) 
  { my $this = shift; return $this->{'hs_content'}; }

=item $port = $sp->GetHTTPServerPort();

Return the TCP/IP port that the HTTP server is listening on.

=cut

sub GetHTTPServerPort($) { my $this = shift; return $this->{'hs_port'}; }

=item $version = $sp->GetHTTPServerVersion();

Return the version number of the HTTP server.

=cut

sub GetHTTPServerVersion($) 
  { my $this = shift; return $this->{'hs_version'}; }

=item return Redirect($url);

Generates appropriate data for a content handler to respond in 
redirecting the browser to $url.

=cut

sub Redirect ($) {
  my $url = shift;
  return new HTTP::Message(
    'status-code' => 301,
    'headers' => { 'location' => $url },
  );
  }

sub RegisteredConnection ($$$;$) {
  my $this = shift;
  my $cid = shift;
  my $direction = shift;
  my $quiet = shift;

  $this->SUPER::RegisteredConnection($cid, $direction, $quiet);
  return if $quiet;
  $this->Log("conn " . uc(substr($direction, 0, 1)) . " $cid "
    . $this->GetConnection($cid)->GetInputHandle()->peerhost() . "\n");
  }

sub ServerName ($) {
  my $this = shift;
  return "HTTP/".$this->GetHTTPServerVersion();
  }

=item $server->SetHTTPServerContentHandler($sub);

Sets the content handler for the server.

=cut

sub SetHTTPServerContentHandler ($$) {
  my $this = shift;
  my $sub = shift;
  $this->{'hs_content'} = $sub;
  }

=item $server->Start() or die;

Give the multiserver our listener port.

=cut

sub Start ($) {
  my $this = shift;
  $this->SetHandle(IO::Socket::INET->new(
    Proto => 'tcp',
    Listen => SOMAXCONN,
    LocalPort => $this->GetHTTPServerPort(),
    Reuse => 1,
    ));
  $this->Log('HTTP server started');
  }

=item return StaticContent($base, $ext[, $request]);

Generates appropriate data for a content handler to respond in serving
the file "$base.$ext".

If the original request is provided, will check If-Modified-Since
against the modification time of the file, and return 304 Not Modified
if appropriate.

=cut

sub StaticContent ($$;$) {
  my $base = shift;
  my $ext = shift;
  my $request = shift;
  my $fn = "$base.$ext";
  my $fh;
  # TODO: should check for if-modified-since
  if (!open $fh, "<", $fn) { 
    # Do not specify an encoding here, could be a binary file
    return new HTTP::Message(
      'status-code' => '404',
      'body' => "File not found: $fn"
      ); 
    }
  my (@stat) = stat $fn;
  my $mtime = (@stat && $stat[9]) || time;
  if ($request) {
    if (my $since = $request->Header('if-modified-since')) {
      $since = HTTP::Message::ParseRFC1123($since);
#     warn "304 $fn"; # DEBUG
      if ($since && $since < $mtime) {
	return new HTTP::Message(
	  'status-code' => 304,
	  'body' => '',
	  'headers' => {},
	  );
        }
      }
    }
  local($/) = undef;
  my $data = <$fh>;
  close($fh);
  my $type = {
    'css' => 'text/css',
    'gif' => 'image/gif',
    'jpeg' => 'image/jpeg',
    'jpg' => 'image/jpeg',
    'js' => 'text/javascript',
    'htm' => 'text/html',
    'html' => 'text/html',
    'ico' => 'image/x-icon',
    }->{$ext};
#   warn "$fn: $type";
  return new HTTP::Message(
    'status-code' => 200,
    'body' => $data,
    'headers' => {
      'content-type' => $type,
      'last-modified' => HTTP::Message::RenderRFC1123($mtime),
      },
    );
  }

=item $server->Shutdown();

Close this server. The multiserver will also shut down the next
time it returns from Run() if there are no other servers running.

=cut

sub Shutdown ($) {
  my $this = shift;
  $this->GetMultiServer()->StopServer($this->GetID());
  }

=back

=cut

1;
