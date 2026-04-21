#!/usr/bin/perl

use strict;
use warnings;

use lib './lib/perl';
use HTTP::Server;

my $s = new HTTP::Server(
  port => 7778,
  content => 
    sub {
      my $request = shift;
      my $http_version = $request->HTTPVersion();
      my $url = $request->URL();
      my $html = '<html><head><title>Server Test</title></head><body><h1>Server Test</h1>';
      $html .= "<h2>Message Start</h2><ul><li>URL: $url</li><li>HTML-Version: $http_version</li></ul>\n";
      $html .= "<h2>Message Headers</h2><ul>";
      my %headers = $request->Headers();
      for my $key (sort keys %headers) {
	$html .= "<li>\u$key: $headers{$key}</li>";
        }
      $html .= "</ul>";
      my $body = $request->Body();
      $html .= "<h2>Message Body</h2><pre>$body</pre>";
      $html .= "</body></html>";
      return new HTTP::Message( 'status-code' => 200, 'body' => $html );
      },
 ) or die;
$s->Start() or die;
while ($s->Run()) {}
$s->Stop();
exit 0;
