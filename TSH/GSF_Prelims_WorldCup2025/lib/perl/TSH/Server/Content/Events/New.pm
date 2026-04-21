#!/usr/bin/perl

# Copyright (C) 2010 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Server::Content::Events::New;

use strict;
use warnings;

use HTTP::Message qw(EncodeEntities);
use TSH::Server qw(HTMLFooter HTMLHeader);

our (@ISA) = qw(TSH::Server::Content);

# This node has no children.
# our $ContentDirectoryPattern = qr[old|new];

=pod

=head1 NAME

TSH::Server::Content::Events::New - render TSH web content for the New Events section 

=head1 SYNOPSIS

  my $renderer = new TSH::Server::Content($server, $request, '/events/new/blah');
  my $message = $renderer->Render();
  
=head1 ABSTRACT

This class renders web content for the New Events section of the TSH web GUI.

=head1 DESCRIPTION

=over 4

=cut

=item $response = $renderer->Render();

Generate the content needed to serve a request for '/events/new/\b.*'.

=cut

sub Render ($) {
  my $this = shift;
  my $tournament = $this->{'server'}->Tournament();
  my $config = $tournament->Config();
  my $paramsp = $this->{'request'}->FormData();
  my $comma = $config->Terminology('comma_space');
  my $t = $config->Terminology({ map { $_ => []}
    qw(EventDate EventDateNote EventID EventIDNote EventName EventNameNote NewEventsMenuBegin NewEventsMenuTitle NumberofRounds NumberofRoundsNote)});

  my $events = join($comma, (map { my $base = $_; $base =~ s!^events/!!; qq(<a href="/events/old/$_/">$base</a>) } grep { -e File::Spec->join($_, 'config.tsh') } (glob('events/*'))));
  $events = $config->Terminology('must_be_different_event', $events) if $events;
  for my $key (qw(event_date event_name id max_rounds)) {
    $paramsp->{$key} = '' unless defined $paramsp->{$key};
    }
  $paramsp->{'id'} =~ s/[^-\w]//g;
  $paramsp->{'max_rounds'} =~ s/\D//g;
  for my $key (keys %$paramsp) {
    $paramsp->{$key} = EncodeEntities $paramsp->{$key};
    }
  my $html = $this->HTMLHeader('Event', 'main') . <<"EOF";
<h1>$t->{'NewEventsMenuTitle'}</h1>
<p class=p1>$t->{'NewEventsMenuBegin'}</p>
<form method="post" enctype="multipart/form-data">
<table border=0 cellpadding=3 cellspacing=0 class=event_data>
<tr>
<td class=id>$t->{'EventID'}</td>
<td class=value><input type="text" name="id" value="$paramsp->{'id'}" size="32" maxlength="64" /></td>
<td class=note>$t->{'EventIDNote'} $events</td>
</tr>
<tr>
<td class=id>$t->{'EventName'}</td>
<td class=value><input type="text" name="event_name" value="$paramsp->{'event_name'}" size="32" maxlength="128" /></td>
<td class=note>$t->{'EventNameNote'}</td>
</tr>
<tr>
<td class=id>$t->{'EventDate'}</td>
<td class=value><input type="text" name="event_date" value="$paramsp->{'event_date'}" size="32" maxlength="128" /></td>
<td class=note>$t->{'EventDateNote'}</td>
</tr>
<tr>
<td class=id>$t->{'NumberofRounds'}</td>
<td class=value><input type="text" name="max_rounds" value="$paramsp->{'max_rounds'}" size="32" maxlength="6" /></td>
<td class=note>$t->{'NumberofRoundsNote'}</td>
</tr>
<tr>
<td colspan=2>&nbsp;</td>
<td>
<input type="submit" tabindex="3" name="create" value="Create Event" />
</td>
</tr>
</table>
</form>
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
