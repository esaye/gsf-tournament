#!/usr/bin/perl

# Copyright (C) 2009 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::BUGreport;

use strict;
use warnings;

use TSH::Utility;
use HTTP::Client;
use HTTP::Message;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::BUGreport - implement the C<tsh> BUGreport command

=head1 SYNOPSIS

  my $command = new TSH::Command::BUGreport;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::BUGreport is a subclass of TSH::Command.

=cut

=head1 DESCRIPTION

=over 4

=cut

sub initialise ($$$$);
sub new ($);
sub Run ($$@);

=item $parserp->initialise()

Used internally to (re)initialise the object.

=cut

sub initialise ($$$$) {
  my $this = shift;
  my $path = shift;
  my $namesp = shift;
  my $argtypesp = shift;

  $this->{'help'} = <<'EOF';
Use this command to report a bug in TSH or ask for help.  
You must be connected to the Internet to send the request.
You should describe your problem in words after the word BUG on the
command line.
EOF
  $this->{'names'} = [qw(bug bugreport)];
  $this->{'argtypes'} = [qw(Expression)];
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
  my (@text) = @_;
  my $config = $tournament->Config();

  my $http = new HTTP::Client('exit_on_error' => 0);
  my $message = new HTTP::Message(
    'method' => 'POST',
    'url' => '/cgi-bin/submit-tsh.pl',
    'headers' => {
      'content-type' => 'multipart/form-data',
      'host' => 'www.poslarchive.com',
      },
    );
  my $note = join('', @text);
  my $rdata = '';
  if (my $profile = $tournament->Profile()) {
    $rdata .= $profile->Render(sub { 0 });
    }
  $rdata .= $config->Render(sub { 1 });
  if (open my $alltsh, '>:encoding(utf8)', $config->MakeRootPath('all.tsh')) {
    print $alltsh $rdata;
    close $alltsh;
    }
  if ($note =~ /^--nosend$/i) {
    print "Created all.tsh but not submitting a report.\n";
    return;
    }
  $message->FormData({
    'password' => 'satire',
    'note' => $note,
    'Confirm' => 1,
    'rdatafile' => { 'type'=>'file', 'filename'=>'all.tsh', 'data'=>$rdata },
    'Upload' => 1,
    });
  $http->Connect('www.poslarchive.com') or return;
  $http->Send($message);
  my $response = $http->Receive();
  my $status = $response->StatusCode();
  my $body = $response->Body();
  if ($status ne '200') {
    print "The submission URL is unreachable ($status).  Either you are having network\nproblems or the server is down.\n";
    }
  elsif ($body =~ /<h1>Software error|red>Unexpected Error/) {
    print "The submission page is reporting a software error.  Please contact John Chew.\n";
    }
  elsif ($body =~ /<p class="?message"?>\n?([^\0]*?)<\/p>/) {
    my $reply = $1;
    $reply =~ s/\n$//;
    $reply =~ s/Warning: .*\n//g;
    $reply =~ s/<\/?span.*?>//g;
    $reply = TSH::Utility::Wrap(2, $reply);
    print "The submission page replies:\n$reply\n";
    }
  elsif ($body =~ /<p class=ok>Thank you/) {
    print "Your report has been received, and e-mail has been sent to John Chew.\n";
    }
  else {
    print "UNEXPECTED ERROR\n---\n$status\n$body\n";
    }
  $http->Close();
  }

=back

=cut

1;
