#!/usr/bin/perl

# Copyright (C) 2006-2019 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::Command::SUBMIT;

use strict;
use warnings;

use TSH::Utility;
use HTTP::Client;
use HTTP::Message;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::SUBMIT - implement the C<tsh> SUBMIT command

=head1 SYNOPSIS

  my $command = new TSH::Command::SUBMIT;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::SUBMIT is a subclass of TSH::Command.

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
Use this command to submit tournament data for ratings calculation
over the Internet.
EOF
  $this->{'names'} = [qw(submit)];
  $this->{'argtypes'} = [qw()];
# print "names=@$namesp argtypes=@$argtypesp\n";

  return $this;
  }

=item $command->CheckNASPA($tournament, $dpsp, \%options);

Do various checks to see if the data should be submitted to NASPA.
Die if something is wrong.

=cut

sub CheckNASPA ($$$$) {
  my $this = shift;
  my $tournament = shift;
  my $dpsp = shift;
  my $optionsp = shift;
  my $config = $tournament->Config();

  eval "use JSON"; 
  if ($@) {
    eval 'sub decode_json($) { my ($data, $rest) = JavaScript::Serializable::FromJSON($_[0]); return $data; }';
    die $@ if $@;
    }

  # fetch event data from NASPA RESTful interface
  my $http = new HTTP::Client('exit_on_error' => 0);
  my $event_data_http = new HTTP::Message(
    'method' => 'GET',
    'url'    => "/rest/v1/tourney/" . $config->Value('tournament_id'),
    'http-version' => '1.1',
    'headers' => { 'host' => $optionsp->{'server_name'}}
  );
  $http->Connect($optionsp->{'server_name'}) or return;
  $http->Send($event_data_http);
  my $edp = decode_json($http->Receive()->Body());

  print "\nNASPA reports the following expectations for the configured event:\n";
  foreach my $key (sort keys %$edp) {
    print "$key:  " . $edp->{$key} . "\n";
    }

  die $edp->{'error_text'} if $edp->{'error_text'};

  # Check to see if event has already been submitted
  die "This event has already been submitted. Email info\@scrabbleplayers.org to report corrections.\n" if $edp->{'submitted'} eq 1;

  # Check start time has passed
  die "Event start time $edp->{'start_time'} is later than local time.\n"
    if $edp->{'start_time'} gt TSH::Utility::Isodate(time);

  # Check end time is not too far in the past
  die "Event end time $edp->{'end_time'} is more than one week ago.\n"
    if $edp->{'end_time'} lt TSH::Utility::Isodate(time()-7*86400);

  # Check rating system (OWL/CSW) and type (COT/ORT/LCT)
  my $expected_rating_system = "";
  if ($edp->{'rating_system'} eq 'owl') {
    $expected_rating_system = "nsa2008";
    }
  elsif ($edp->{'rating_system'} eq 'csw') {
    $expected_rating_system = "naspa-csw";
    }
  else {
    $tournament->TellUser('wsubmitratsys', $edp->{'rating_system'} );
    }

  my $expected_event_type = "";
  if ($edp->{'type'} =~ /^(?:lct|cot)$/) {
    $expected_rating_system .= " lct";
    }
  elsif ($edp->{'type'} ne 'ort') {
    $tournament->TellUser('wsubmittype', $edp->{'type'} );
    }

  if ($expected_rating_system ne $config->Value('rating_system')) {
    die 'Configured rating system ' . $config->Value('rating_system') 
      . ' does not correspond to expected: ' 
      . $expected_rating_system . "\n";
#     . uc ($edp->{'rating_system'} . '/' . $edp->{'type'});
    }

  # Check director ID
  if ($edp->{'director_naspa'} ne $config->Value('director_id')) {
    die 'Configured director ID ' . $config->Value('director_id') 
      . ' does not correspond to expected: ' . $edp->{'director_naspa'} . "\n";
    }

  # Check data dimensions
  foreach my $dp (@{$dpsp}) {
    if ($dp->LastPairedScoreRound0() > $dp->MaxRound0()) {
      die sprintf('Div %s has data for more rounds (%d) than are permitted in its config (%d)\n',
	$dp->Name(),
	$dp->LastPairedScoreRound0()+1,
	$dp->MaxRound0()+1);
      }
    if ($dp->CountPlayers() < 4) {
	die sprintf('Div %s has too few players to be rated (%d)\n',
	  $dp->Name(),
	  $dp->CountPlayers());
      }
    }
  }

sub new ($) { return TSH::Utility::new(@_); }

=item $command->Run($tournament, @parsed_args)

Should run the command in the context of the given
tournament with the specified parsed arguments.

=cut

sub Run ($$@) { 
  my $this = shift;
  my $tournament = shift;
  my (@absp, @nor, @nsa);
  for my $dp ($tournament->Divisions()) {
    my $rs = $dp->RatingSystemName();
    if ($rs eq 'absp') {
      push(@absp, $dp);
      }
    elsif ($rs eq 'none') {
      $tournament->TellUser('wsubmitnone', $dp->Name());
      }
    elsif ($rs eq 'nor') {
      push(@nor, $dp);
      }
    else {
      push(@nsa, $dp);
      }
    }
  if (@nor) {
    $tournament->TellUser('isubmitnor', join (', ', map { $_->Name() } @nor));
    $this->SubmitNOR($tournament, @nsa);
    }
  if (@nsa) {
    $tournament->TellUser('isubmitnsa', join (', ', map { $_->Name() } @nsa));
    # TODO: \@nsa is being ignored in favour of an alternate test in SubmitNASPA
    $this->SubmitNASPA($tournament, \@nsa);
    }
  if (@absp) {
    $tournament->TellUser('isubmitabsp', join (', ', map { $_->Name() } @absp));
    $this->SubmitABSP($tournament, \@absp);
    }
  }

=item $command->LoginABSP($tournament);

Get a login cookie from the ABSP website.

=cut

sub LoginABSP ($$$;$) { 
  my $this = shift;
  my $tournament = shift;
  my $config = $tournament->Config();
  my $password;
# my $server_name = 'www.myscrabbleapp.com';
  my $server_name = 'www.absp-database.org';

  my $http = new HTTP::Client('exit_on_error' => 0);
  my $message = new HTTP::Message(
    'method' => 'POST',
    'url' => '/absp_log_on_or_off.php',
    'headers' => {
      'content-type' => 'multipart/form-data',
      'user-agent' => 'tsh.poslfit.com',
      'host' => $server_name,
      },
    );

  my $username = $config->Value('director_email');
  {
    $| = 1;
    print "Username: $username\n";
    print "Password: ";
    $password = TSH::Utility::ReadPassword();
    print "\n";
  }
  $message->FormData({
    'username' => $username,
    'password' => $password,
    'action' => 'password_logon',
#   'submit' => 'Log in',
    });
  $http->Connect($server_name) or do { warn "Connection failed.\n"; return; };
  $http->Send($message);
  my $response = $http->Receive();
  my $status = $response->StatusCode();
  my $body = $response->Body();
  my $cookie = $response->Header('Set-Cookie');
# warn $status;
# warn $response;
# warn $body;
  if (0 and $body !~ /Logged on/) { # authentication no longer sends response body
    if ($username eq 'poslfit@gmail.com') {
      my $h = $response->{'headers'};
      warn join('', map { "$_: $h->{$_}\n" } sort keys %$h);
      warn "status: $status\n";
      if (defined $body) { warn "BODY:\n$body\n"; }
      else { warn "NO BODY\n"; }
      if (defined $cookie) { warn "COOKIE: $cookie\n"; }
      else { warn "NO COOKIE\n"; }
      }
    warn "Login failed.\n"; 
    return undef; 
    }
  if (not defined $cookie) {
    warn "Login failed.\n";
    return undef;
    }
  if ($cookie and $cookie =~ s/;.*//) {
    return $cookie;
    }
  print "Can't parse authentication cookie '$cookie': please contact John Chew at poslfit\@gmail.com.\n";
  return undef;
  }

=item $command->SubmitABSP($tournament, \@divsi [,\%options]);

Submits ratings data to the ABSP.  Does the same as

% curl -c cookie.txt -F username=poslfit@gmail.com -F password=temp63 -F action=password_logon http://www.myscrabbleapp.com/absp_log_on_or_off.php > /dev/null
% cd test
% curl --trace-ascii /tmp/trace -b ../cookie.txt -F submit="Upload tsh files" -F tournament=16972 -F 'userfile[]=@config.tsh' -F 'userfile[]=@a.t' -F 'userfile[]=@b.t' http://www.myscrabbleapp.com/upload_tsh.php

=cut

sub SubmitABSP ($$$;$) { 
  my $this = shift;
  my $tournament = shift;
  my $dpsp = shift;
  my $optionsp = shift;
  my $password;

  my $request_uri = $optionsp->{'request_uri'} || '/upload_tsh.php';
  my $server_name = $optionsp->{'server_name'} || 'www.absp-database.org';
  my $want_error = $optionsp->{'want_error'};

  my $rdata = '';
  if (my $profile = $tournament->Profile()) {
    $rdata = $profile->Render();
    }
  my $config = $tournament->Config();
  $rdata .= $config->Render(sub{1});
  if (1 and $config->Value('director_email') eq 'poslfit@gmail.com') {
    if (open my $fh, '>', '/tmp/absp.txt') {
      print $fh $rdata;
      warn "See /tmp/absp.txt for submission data.\n";
      }
    }
  for my $key (qw(director_email tournament_id)) {
    unless ($config->Value($key)) {
      print "You are strongly encouraged to specify config $key in your config.tsh file,\nto avoid having to retype it here, but for now...\n";
      TSH::Utility::Prompt "Enter your $key:";
      my $input = $config->DecodeConsoleInput(scalar(<STDIN>));
      chomp $input;
      $config->Value($key, $input);
      }
    }
  my $cookie = $this->LoginABSP($tournament);
  unless ($cookie) {
    print "Authentication failure.\n";
    return;
    }
  if (1 and $config->Value('director_email') eq 'poslfit@gmail.com') {
    warn "Detected developer access, reporting rendered submission data.\n\n"
      . "server_name: $server_name\n"
      . "request_uri: $request_uri\n";
#     . "submission data:\n$rdata\n";
    }
# die "Auth OK: $cookie";
  my $http = new HTTP::Client('exit_on_error' => 0);
  my $message = new HTTP::Message(
    'method' => 'POST',
    'url' => $request_uri,
    'headers' => {
      'content-type' => 'multipart/form-data',
      'user-agent' => 'tsh.poslfit.com',
#     'host' => 'localhost',
      'host' => $server_name,
      'cookie' => $cookie,
      },
    );
  my $note = $config->Value('ratings_note') || '';
  $note .= " Automatically submitted from tsh $::gkVersion.";
  $message->FormData({
    'tournament' => $config->Value('tournament_id'),
    'submit' => 'Upload tsh files',
    'userfile[]' => [
      {'type'=>'file', 'filename'=>'config.tsh', 'data'=>$rdata},
      map { 
        { 'type' => 'file', 'filename' => $_->File(), 'data' => $_->Render(
	  { 'pname_canonicaliser' => \&Ratings::ABSP::Canonicalise},
	  { 'suppress_bye_p12' => 1 },
	) }
        } @$dpsp
      ],
    });
  $http->Connect($server_name) or return;
  $http->Send($message);
# print "Sending:\n---\n", $message->ToString(), "\n---\n";
  my $response = $http->Receive();
  my $status = $response->StatusCode();
  my $body = $response->Body();
  TSH::Utility::ReplaceFile($config->MakeRootPath('absp-reply.html'), $body);
# print "Received:\n---\n$body\n---\n";
  if ($want_error) {
    if ($status eq '200') {
      if ($body eq 'Ok') { return ''; }
      else { return "Server replied: $body."; }
      }
    else { return "Server returned code $status."; }
    }
  if ($status ne '200') {
    print "The submission URL appears unreachable ($status).  Either you are having network\nproblems or the server is down.\n";
    print "But sometimes the server returns a 503 status after data is posted;\nit's worth checking online to see if the data is there.\n"
      if $status eq '503';;
    if (1 and $config->Value('director_email') eq 'poslfit@gmail.com') {
      warn "Detected developer access, reporting additional data.\n\n"
        . "server_name: $server_name\n"
        . "request_uri: $request_uri\n"
	. "full response body:\n$body\n";
      }
    }
  elsif (my (@errors) = $body =~ /<div class="?tsh_error"?>([^\0]*)<\/div>/g) {
    print "The submission page reports the following errors:\n\n";
    print join("\n\n", @errors);
    }
  elsif (my (@status) = $body =~ /<div class="?tsh_success"?>([^\0]*)<\/div>/g) {
    print "The submission page reports that it has received your data:\n\n";
    print join("\n\n", @status);
    print "You should now review your data on the website, and report its submission.\n";
    my $url = "http://$server_name/view_absp_tournament.php?tournament="
      . $config->Value('tournament_id');
    print "$url\n";
    TSH::Utility::Browse($url);
    }
  else {
    print "The submission page did not respond in an expected manner.\n";
    print "Its response is available as absp-reply.html in your event folder.\n";
    }
  $http->Close();
  }

=item $command->SubmitNOR($tournament);

Submits ratings data to the Norwegian authority.

=cut

sub SubmitNOR ($$@) { 
  my $this = shift;
  my $tournament = shift;
  my (@dps) = @_;
  my $config = $tournament->Config();
  my $rdata = $config->Render(sub { $_[0]->RatingSystemName() =~ /^nor$/i; });
  if (open my $alltsh, '>:encoding(utf8)', $config->MakeRootPath('all.tsh')) {
    print $alltsh $rdata;
    close $alltsh;
    }
# for my $key (qw(director_id tournament_id)) {
  for my $key (qw()) {
    unless ($config->Value($key)) {
      print "You must specify config $key to use this command.\n";
      return 0;
      }
    }
  my $http = new HTTP::Client('exit_on_error' => 0);
  my $message = new HTTP::Message(
    'method' => 'POST',
    'url' => '/cgi-bin/tsh/submit.py',
    'headers' => {
      'content-type' => 'multipart/form-data',
      'user-agent' => 'tsh.poslfit.com',
#     'host' => 'localhost',
      'host' => 'scrabbeller.scrabbleforbundet.no',
      },
    );
  my $note = $config->Value('ratings_note') || '';
  $note .= " Automatically submitted from tsh $::gkVersion.";
# my $password = $config->Value('director_password');
# unless (defined $password) {
#   $| = 1;
#   print "Password: ";
#   $password = TSH::Utility::ReadPassword();
#   print "\n";
#   }
  $message->FormData({
#   'username' => $config->Value('director_id'),
#   'password' => $password,
#   'poslid_submit_login' => 1,
#   'tournament_id' => $config->Value('tournament_id'),
#   'note' => $note,
    'rdatafile' => { 'type'=>'file', 'filename'=>'all.tsh', 'data'=>$rdata },
#   'Confirm' => 1,
    });
  $http->Connect('scrabbeller.appspot.com') or return;
  $http->Send($message);
  my $response = $http->Receive();
  my $status = $response->StatusCode();
  my $body = $response->Body();
  if ($status ne '200') {
    print "URL-en kan ikke nås ($status).\nEnten har du nettverksproblemer, eller så er sørveren nede.\n";
    }
  elsif ($body =~ s/^ERROR\n//) {
    print <<"EOF";
Rapporteringssiden melder fra om softwareproblemer. Vennligst ta
kontakt med den ratingansvarlige og kopier og lim inn den følgende
meldingen:

$body
EOF
    }
  elsif ($body =~ s/^OK\n//) {
    my $message = "Ratingdataene dine har blitt akseptert.\n";
    $message =~ s/\n$/  Nettsiden rapporterer: \n\n$body\n/ if $body =~ /\S/;
    }
  else {
    print "UVENTET SØRVERRESPONS\n---\n$status\n$body\n";
    }
  $http->Close();
  }

=item $command->SubmitNASPA($tournament, \@divsi [,\%options]);

Submits ratings data to NASPA.

=cut

sub SubmitNASPA ($$$;$) { 
  my $this = shift;
  my $tournament = shift;
  my $dpsp = shift;
  my $optionsp = shift;

  my $request_uri = $optionsp->{'request_uri'} || '/cgi-bin/submit-rdata.pl';
  # Set param "test=1" for test submission
  my $server_name = $optionsp->{'server_name'} || 'www.scrabbleplayers.org';
  my $want_error = $optionsp->{'want_error'};

  my $rdata = '';
  if (my $profile = $tournament->Profile()) {
    $rdata = $profile->Render();
    }
  my $config = $tournament->Config();
  $rdata .= $config->Render(sub { $_[0]->RatingSystemName() =~ /\b(?:nsa|naspa)/; });
  if (open my $alltsh, '>:encoding(utf8)', $config->MakeRootPath('all.tsh')) {
    print $alltsh $rdata;
    close $alltsh;
    }
  for my $key (qw(director_id tournament_id)) {
    unless ($config->Value($key)) {
      print "You must specify config $key to use this command.\n";
      return 0;
      }
    }

  # Additional data checks

  if ($config->Value('no_suppress_submit_checks')) {
    eval { $this->CheckNASPA($tournament, $dpsp, {'server_name'=>$server_name}); };
    if ($@) {
      my $why = $@;
      $why =~ s/\n[^\0]*//;
      $tournament->TellUser('esubmitcheck', $why);
      return 0;
      }
    }
  # End data checks

  my $http = new HTTP::Client('exit_on_error' => 0);
  my $message = new HTTP::Message(
    'method' => 'POST',
    'url' => $request_uri,
    'headers' => {
      'content-type' => 'multipart/form-data',
      'user-agent' => 'tsh.poslfit.com',
#     'host' => 'localhost',
      'host' => $server_name,
      },
    );
  my $note = $config->Value('ratings_note') || '';
  $note .= " Automatically submitted from tsh $::gkVersion.";
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
    'tournament_id' => $config->Value('tournament_id'),
    'note' => $note,
    'rdatafile' => { 'type'=>'file', 'filename'=>'all.t', 'data'=>$rdata },
    'Confirm' => 1,
#   @unrated_flags,
    });
  $http->Connect($server_name) or return;
  $http->Send($message);
# print "Sending:\n---\n", $message->ToString(), "\n---\n";
  my $response = $http->Receive();
  my $status = $response->StatusCode();
  my $body = $response->Body();
# print "Received:\n---\n$body\n---\n";
  if ($want_error) {
    if ($status eq '200') {
      if ($body eq 'Ok') { return ''; }
      else { return "Server replied: $body."; }
      }
    else { return "Server returned code $status."; }
    }
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
  elsif ($body =~ /<p class=report>\s*([^\0]*?)<\/p>/) {
    my $reply = $1;
    $reply =~ s/<br>/\n/g; 
    $reply =~ s/\n{2,}/\n/g;
    $reply =~ s/^\n//;
    $reply =~ s/\n$//;
    $reply =~ s/Warning: .*\n//g;
    $reply =~ s/<\/?span.*?>//g;
    $reply = TSH::Utility::Wrap(2, $reply);
    print "The submission page replies:\n$reply\n";
    }
  elsif ($body =~ /: Payment Redirect/) {
    my $payment_url = 'http://www.scrabbleplayers.org/cgi-bin/account.pl';
    print "Your ratings submission has been accepted.\nYou should now go online to pay the participation fee:\n$payment_url\nI'll try to open a browser window for you.";
    TSH::Utility::Browse($payment_url);
    }
  elsif ($body =~ /NASPA: Login/) {
    print "Password incorrect.\n";
    }
  else {
    print "UNEXPECTED ERROR\n---\n$status\n$body\n";
    }
  $http->Close();
  }

=back

=cut

1;
