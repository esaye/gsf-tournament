#!/usr/bin/perl

# Copyright (C) 2010 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Server::Content;

use strict;
use warnings;
use TSH::Utility;

# our (@ISA) = qw(Exporter);
# our (@EXPORT_OK) = qw();

=pod

=head1 NAME

TSH::Server::Content - render web content for the TSH GUI 

=head1 SYNOPSIS

  my $renderer = new TSH::Server::Content($this, $request, $url, $client);
  return $renderer->Render();
    
=head1 ABSTRACT

This class renders web content for the TSH web GUI.

=head1 DESCRIPTION

=over 4

=cut

my (%url_rewrite) = (
  '/favicon.ico' => '/doc/tsh.ico',
  '/tsh.css' => "/lib/tsh.css",
  );
my (%url_dispatch) = (
  qr(^/index\.html$) => 'ContentRoot',
  qr(^/(config|profile)/index\.html$) => 'ContentConfig',
  qr[^/(\w+)-(alpha-pairings|pairings|ratings)-(\d+).html$] => 'ContentReport',
  qr[^/division/(\w+)(?:/index\.html)?$] => 'ContentDivision',
  qr[^/doc(/\w+)\.(css|html|ico)$] => 'ContentDocumentationFramed',
  qr[^/docraw(/\w+)\.(css|html|ico)$] => 'ContentDocumentationUnframed',
  qr[^/lib/(tsh)\.(css)$] => 'ContentLibraryFile',
  qr[^/lib/(gui/.*)\.(gif)$] => 'ContentLibraryFile',
  qr[^/pix(/[^\0.]+)\.(gif|jpe?g|png)$] => 'ContentPhoto',
  qr[^/js(/[-\w]+)\.(js)$] => 'ContentJavaScript',
  qr[^/report/([-\w]+)\.(css|html)$] => 'ContentStaticReport',
  qr[^/cgi/sss$] => 'ContentSelfServiceScoring',
  qr[^/shutdown] => 'ContentShutdown',
  );

sub ClientAddress ($) {
  my $this = shift;
  return HTTP::Server::ClientHost($this->{'client'});
  }

# URL patterns that lead to subclass delegation
our $ContentDirectoryPattern = qr[events];

sub Dispatch ($) {
  my $this = shift;
  my $pattern = eval '$' . ref($this) . '::ContentDirectoryPattern';
  return unless defined $pattern;
  # if matched pattern
  if ($this->{'url'} =~ s!^/($pattern)\b!!) {
    # load subclass
    my $subclass = ref($this) . '::' . ucfirst $1;
    eval "use $subclass";
    die $@ if $@;
    # delegate to subclass
    bless $this, $subclass;
    $this->Dispatch();
    }
  }

sub initialise ($$$$$) {
  my $this = shift;
  $this->{'server'} = shift;
  $this->{'request'} = shift;
  $this->{'url'} = shift;
  $this->{'client'} = shift;
  $this->Dispatch();
  }

sub new ($$$$) { return TSH::Utility::new(@_); }

=item $response = $server->Render($server, $request, $suburl);

Generate the content needed to serve a request for '/.*'.

=cut

sub Render ($) {
  my $this = shift;

# if ($this->{'url'} !~ m/(?:\.(?:css|ico)|^\/(?:doc|events|js|pix|shutdown)\b.*|^\/(?:index\.html)?)$/ && (my $error = ConfigCheck())) { return $this->{'server'}->ContentConfig($this->{'request'}, {'error'=>$error}); }
  # canonicalise
  if ($this->{'url'} =~ /^\/[^.\/]+$/) 
    { return HTTP::Server::Redirect("$this->{'url'}/"); }
  $this->{'url'} .= "index.html" if $this->{'url'} =~ /\/$/;
  $this->{'url'} = $url_rewrite{$this->{'url'}} || $this->{'url'};
  $this->{'url'} =~ s/\/{2,}/\//g;
  while ($this->{'url'} =~ s/\/\.\//\//g) {} 
  while ($this->{'url'} =~ s/\/([^\/]+)\/\.\.\//\//g) { }
  # older dispatch method for recognized requests
  keys %url_dispatch; # reset 'each' iterator
  while (my ($pattern, $method) = each %url_dispatch) {
    if (my (@argv) = ($this->{'url'} =~ $pattern)) {
      no strict qw(refs);
      return $this->{'server'}->$method($this->{'request'}, $this->{'url'}, @argv);
      }
    }
  # else display error message
  my $html = "<h1>Unrecognized URL: $this->{'url'}</h1>";
  $html .= "<p>Here are the details of the request you sent.</p>";
  $html .= "<h2>Message Start</h2><ul><li>Method: ".($this->{'request'}->Method())."</li><li>URL: ".($this->{'request'}->URL())."</li><li>HTML-Version: ".($this->{'request'}->HTTPVersion())."</li></ul>\n";
  $html .= "<h2>Message Headers</h2><ul>";
  my %headers = $this->{'request'}->Headers();
  for my $key (sort keys %headers) {
    $html .= "<li>\u$key: $headers{$key}</li>";
    }
  $html .= "</ul>";
  $html .= "<h2>Message Body</h2><pre>" . ($this->{'request'}->Body()) . "</pre>";
  $html .= "</body></html>";
  return new HTTP::Message( 'status-code' => 404, 'body' => $html );
  }

=back

=cut

1;
