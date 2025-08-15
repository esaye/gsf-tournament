#!/usr/bin/perl

# Copyright (C) 2009 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::TWEET;

use strict;
use warnings;

use TSH::Utility;
use HTTP::Client;
use HTTP::Message;

our (@ISA) = qw(TSH::Command);

BEGIN {
  &main::Use('MIME::Base64');
  }

=pod

=head1 NAME

TSH::Command::TWEET - implement the C<tsh> TWEET command

=head1 SYNOPSIS

  my $command = new TSH::Command::TWEET;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::TWEET is a subclass of TSH::Command.

=cut

=head1 DESCRIPTION

=over 4

=cut

sub initialise ($$$$);
sub new ($);
sub RenderPlayerName ($$);
sub Run ($$@);
sub Tweet ($$@);

=item $parserp->initialise()

Used internally to (re)initialise the object.

=cut

sub initialise ($$$$) {
  my $this = shift;
  my $path = shift;
  my $namesp = shift;
  my $argtypesp = shift;

  $this->{'help'} = <<'EOF';
Use this command to tweet (post a message to twitter.com)
describing the situation in a division.
EOF
  $this->{'names'} = [qw(tweet)];
  $this->{'argtypes'} = [qw(Division Player Player)];
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
  my $dp = shift;
  my $pn1 = shift;
  my $pn2 = shift;

  # check that division is not partially scored
  my $r1 = $dp->LastPairedScoreRound0()+1;
  if ($r1 > $dp->LeastScores()) {
    $tournament->TellUser('emisss3', $dp->Name(), $r1, $dp->LeastScoresPlayer()->TaggedName());
    return 0;
    }

  my $psp = $dp->GetUnpaired('empty ok');
  if (@$psp != 0) {

    }

  my $s = $this->RenderTweet($dp, $pn1, $pn2);
  $this->SendTweet($s);
  }

sub RenderPlayerName ($$) {
  my $p = shift;
  my $fat_tweets = shift;
  my $twitter_name = $p->TwitterName();
  return "\@$twitter_name" if $twitter_name;
  my $name = join(' ', @{$p->ScoreBoardNames()||[]}) || $p->LocaliseName();
  $name =~ s/(.*), (.*)/$2 $1/;
  $name =~ s/ //g unless $fat_tweets;
  return $name;
  }

=item $s = $command->RenderTweet($dp, $pn1, $pn2);

Render an appropriate tweet.

=cut

sub RenderTweet ($$@) { 
  my $this = shift;
  my $dp = shift;
  my $pn1 = shift;
  my $pn2 = shift;
  my $s = ''; # ultimately, the tweet
  my $length;
  my @s; # array of reference to array describing player status
  
  my $tourney = $dp->Tournament();
  my $config = $tourney->Config();
  if (my $prefix = $config->Value('twitter_prefix')) {
    $s = "$prefix ";
    }
  my $fat_tweets = $config->Value('fat_tweets');
  my $colon_padding = $fat_tweets ? '  ' : '';
  $length = length($s);
  my (@players) = (TSH::Player::SortByCurrentStanding $dp->Players())[$pn1-1..$pn2-1];
  my $dname = $tourney->CountDivisions() > 1 ? $dp->Name() : '';
  if ($dname =~ /\d$/) { $dname = "Div $dname:"; }
  {
    my $lastw = -1;
    for my $i (0..$#players) {
      my $p = $players[$i];
      my $name = $dname . ($i+1) . ':' . RenderPlayerName $p, $fat_tweets;
      $dname = '';
      my $w = $p->Wins();
      if ($fat_tweets || $w != $lastw) {
	$lastw = $w;
	my $record = $p->Wins() . '-' . $p->Losses() . ' ';
	$name =~ s/:/:$colon_padding$record/;
        }
      if (length($name) + $length < 139) {
	push(@s, [$name]);
	$length += length($name) + 1;
	}
      else {
	last;
        }
      }
  }
  for my $i (0..$#s) {
    my $sp = $s[$i];
    last unless $fat_tweets || @$sp >= 2;
    my $p = $players[$i];
    my $spread = sprintf("%+d", $p->Spread());
    if (length($spread) + $length < 139) {
      push(@{$s[$i]}, $spread);
      $length += length($spread) + 1;
      }
    }
  for my $i (0..$#s) {
    my $sp = $s[$i];
    last unless $fat_tweets || @$sp >= 2;
    my $p = $players[$i];
    my $r0 = $p->CountScores() - 1;
    my $oid = $p->OpponentID($r0);
    my $score = $oid ? $p->Score($r0) . '-' . $p->OpponentScore($r0)
      : $p->Score($r0);
    if (length($score) + $length < 139) {
      push(@{$s[$i]}, $score);
      $length += length($score) + 1;
      }
    }
  for my $i (0..$#s) {
    my $sp = $s[$i];
    last unless $fat_tweets || @$sp >= 3;
    my $p = $players[$i];
    my $r0 = $p->CountScores() - 1;
    my $opp = $p->Opponent($r0);
    my $oname = $opp ? 'v ' . (RenderPlayerName $opp, $fat_tweets) : 'bye';
    if (length($oname) + $length < 139) {
      push(@{$s[$i]}, $oname);
      $length += length($oname) + 1;
      }
    }
  $s .= join(
    ($fat_tweets ? "\n" : ($length + @s < 140) ? '. ' : ' '),
    map { join(' ', @$_) } @s);
  return $s;
  }

=item $s = $command->SendTweet($s);

Tweet to twitter.

=cut

sub SendTweet ($$) {
  my $this = shift;
  my $s = shift;
  my $tourney = $this->Processor()->Tournament();
  my $config = $tourney->Config();

  my $command = $config->Value('twitter_command');
  unless (defined $command) {
    $tourney->TellUser('eneedtwitc');
    return 0;
    }

  $command = sprintf($command, $s);
  print "Trying to tweet: $command\n";
  system $command;
  return 0;

  print "Trying to tweet: $s\n";
  # rest was obsoleted by Twitter's security changes in 2011-2012
  my $username = $config->Value('twitter_username');
  unless (defined $username) {
    $tourney->TellUser('eneedtwitu');
    return 0;
    }
  my $password = $config->Value('twitter_password');
  unless (defined $password) {
    $tourney->TellUser('eneedtwitp');
    return 0;
    }
  my $base64 = MIME::Base64::encode_base64("$username:$password");
  chomp $base64;

  my $http = new HTTP::Client('exit_on_error' => 0);
  my $message = new HTTP::Message(
    'method' => 'POST',
    'url' => '/statuses/update.xml',
    'headers' => {
      'content-type' => 'multipart/form-data',
#     'host' => 'localhost',
      'host' => 'twitter.com',
      'authorization' => "Basic $base64",
      },
    );
  $message->FormData({
    'status' => $s,
    });
  $http->Connect('twitter.com') or return;
  $http->Send($message);
  print "Sending:\n---\n", $message->ToString(), "\n---\n";
  my $response = $http->Receive();
  my $status = $response->StatusCode();
  my $body = $response->Body();
# print "Received:\n---\n$body\n---\n";
  if ($status ne '200') {
    print "The submission URL is unreachable ($status).  Either you are having network\nproblems or the server is down.\n";
    }
  elsif ($body =~ m!<truncated>(\w+)</truncated>!) {
    if ($1 eq 'false') {
      $tourney->TellUser('itweetok', $s);
      }
    else {
      $tourney->TellUser('wtweettrunc');
      }
    }
  else {
    print "I can't understand twitter.com's reply:\n$body\n";
    }
  $http->Close();
  }

=back

=cut

=head1 BUGS

Broke in 2011 following security changes on Twitter, this module is 
not currently working.  

Should take a look at http://www.floodgap.com/software/ttytter/ for coding ideas.

=cut

1;
