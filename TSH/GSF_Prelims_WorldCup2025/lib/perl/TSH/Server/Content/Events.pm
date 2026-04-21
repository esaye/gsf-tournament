#!/usr/bin/perl

# Copyright (C) 2010 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Server::Content::Events;

use strict;
use warnings;

use TSH::Server qw(HTMLFooter HTMLHeader);

our (@ISA) = qw(TSH::Server::Content);

our $ContentDirectoryPattern = qr[old|new];

=pod

=head1 NAME

TSH::Server::Content::Events - render TSH web content for the Events section 

=head1 SYNOPSIS

  my $renderer = new TSH::Server::Content($server, $request, '/events/blah');
  my $message = $renderer->Render();
  
=head1 ABSTRACT

This class renders web content for the Events section of the TSH web GUI.

=head1 DESCRIPTION

=over 4

=cut

=item $response = $renderer->Render();

Generate the content needed to serve a request for '/events\b.*'.

=cut

sub Render ($) {
  my $this = shift;

  my $tournament = $this->{'server'}->{'tournament'};
  my $config = $tournament->Config();
  my $html = $this->{'server'}->HTMLHeader('Events', 'main');
  my $comma = $config->Terminology('comma_space');
  my $top_events = join($comma, (map { qq(<a href="/events/old/$_/">$_</a>) } grep { -e File::Spec->join($_, 'config.tsh') } glob('*')));
  $top_events = '<li>' . $config->Terminology('EventsMenuOpenTop', $top_events) . '</li>' if $top_events;
  my $sub_events = join($comma, (map { my $base = $_; $base =~ s!^events/!!; qq(<a href="/events/old/$_/">$base</a>) } grep { -e File::Spec->join($_, 'config.tsh') } glob('events/*')));
  $sub_events = '<li>' . $config->Terminology('EventsMenuOpenSub', $sub_events) . '</li>' if $sub_events;
  my $t = $config->Terminology({map { $_ => [] } 
    qw(EventsMenuTitle EventsMenuNewItem wwyltd)});
  $html .= <<"EOF";
<h1>$t->{'EventsMenuTitle'}</h1>
<p class=p1>$t->{'wwyltd'}</p>
<ul>
<li>$t->{'EventsMenuNewItem'}</li>
$sub_events
$top_events
</ul>
EOF
  $html .= HTMLFooter();
  return new HTTP::Message(
    'status-code' => 200,
    'body' => $html,
    );
  }

=back

=cut

1;
