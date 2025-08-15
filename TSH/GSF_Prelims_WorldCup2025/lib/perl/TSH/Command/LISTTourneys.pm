#!/usr/bin/perl

# Copyright (C) 2006 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::LISTTourneys;

use strict;
use warnings;

use TSH::Utility;
use HTTP::Client;
use HTTP::Message;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::LISTTourneys - implement the C<tsh> LISTTourneys command

=head1 SYNOPSIS

  my $command = new TSH::Command::LISTTourneys;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::LISTTourneys is a subclass of TSH::Command.

=cut

=head1 DESCRIPTION

=over 4

=cut

sub initialise ($$$$);
sub new ($);
sub Run ($$@);
sub ListNASPA ($$@);

=item $parserp->initialise()

Used internally to (re)initialise the object.

=cut

sub initialise ($$$$) {
  my $this = shift;
  my $path = shift;
  my $namesp = shift;
  my $argtypesp = shift;

  $this->{'help'} = <<'EOF';
Use this command to list tournaments for which you can submit rating data
over the Internet.
EOF
  $this->{'names'} = [qw(listt listtourneys)];
  $this->{'argtypes'} = [qw()];
# print "names=@$namesp argtypes=@$argtypesp\n";

  return $this;
  }

sub new ($) { return TSH::Utility::new(@_); }

=item $command->Run($tournament, @parsed_args)

Should run the command in the context of the given
tournament with the specified parsed arguments.

=cut

sub Run ($$@) { 
  my $this = shift;
  my $tournament = shift;
  my @naspa;
  my $absp;
  for my $dp ($tournament->Divisions()) {
    my $rs_name = $dp->RatingSystemName();
    if ($rs_name eq 'absp') {
      $tournament->TellUser('esubmitabsp') unless $absp++;
      }
    elsif ($rs_name eq 'none') {
      $tournament->TellUser('wsubmitnone', $dp->Name());
      }
    else {
      push(@naspa, $dp);
      }
    }
  if (@naspa) {
#   $tournament->TellUser('isubmitnaspa', join (', ', map { $_->Name() } @naspa));
    $this->ListNASPA($tournament);
    }
  }

=item $command->ListNASPA($tournament);

Lists pending NASPA tournaments.

=cut

sub ListNASPA ($$@) { 
  my $this = shift;
  my $tournament = shift;
  my (@dps) = @_;
  my $config = $tournament->Config();
  my $rdata = $config->Render(sub { $_[0]->RatingSystemName() =~ /\bnaspa/; });
  for my $key (qw(director_id)) {
    unless ($config->Value($key)) {
      print "You must specify config $key to use this command.\n";
      return 0;
      }
    }
  my $http = new HTTP::Client('exit_on_error' => 0);
  my $message = new HTTP::Message(
    'method' => 'POST',
    'url' => '/cgi-bin/list-my-tourneys.pl',
    'headers' => {
      'content-type' => 'multipart/form-data',
      'user-agent' => 'tsh.poslfit.com',
#     'host' => 'localhost',
      'host' => 'www.scrabbleplayers.org',
      },
    );
  my $password = $config->Value('director_password');
  unless (defined $password) {
    $| = 1;
    print "Password: ";
    $password = TSH::Utility::ReadPassword();
    print "\n";
    }
  $message->FormData({
    'username' => $config->Value('director_id'),
    'password' => $password,
    'poslid_submit_login' => 1,
    'Confirm' => 1,
    });
  $http->Connect('www.scrabbleplayers.org') or return;
# $http->Connect('localhost') or return;
  $http->Send($message);
# print "Sending:\n---\n", $message->ToString(), "\n---\n";
  my $response = $http->Receive();
  my $status = $response->StatusCode();
  my $body = $response->Body();
# print "Received:\n---\n$body\n---\n";
  if ($status ne '200') {
    print "The submission URL is unreachable ($status).  Either you are having network\nproblems or the server is down.\n";
    }
  elsif ($body =~ /<h1>Software error|red>Unexpected Error/) {
    print "The submission page is reporting a software error.  Please contact John Chew.\n";
    if ($config->Value('director_id') eq 'CM000003') {
      open my $error, '>:encoding(utf8)', $config->MakeRootPath('error.html');
      print $error $body;
      }
    }
  else { 
    print "The server replies:\n$body\n";
    }
  $http->Close();
  }

=back

=cut

1;
