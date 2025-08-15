#!/usr/bin/perl

# Copyright (C) 2014 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::Command::TWeetPairings;

use strict;
use warnings;

use TSH::Log;
use TSH::Utility qw(Debug DebugOn OpenFile Ordinal);

# DebugOn('SP');

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::TWeetPairings - implement the C<tsh> TWeetPairings command

=head1 SYNOPSIS

  my $command = new TSH::Command::TWeetPairings;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::TWeetPairings is a subclass of TSH::Command.

=cut

=head1 DESCRIPTION

=over 4

=cut

sub initialise ($@);
sub new ($);
sub Run ($$@);

=item $parserp->initialise()

Used internally to (re)initialise the object.

=cut

sub initialise ($@) {
  my $this = shift;

  $this->SUPER::initialise(@_);
  $this->{'help'} = <<'EOF';
Use this command to tweet the pairings to all players in the division whose 
twitter handles are known.
EOF
  $this->{'names'} = [qw(twp tweetpairings)];
  $this->{'argtypes'} = [qw(Round Division)];

  return $this;
  }

sub new ($) { return TSH::Utility::new(@_); }

sub TweetPair ($$$) {
  my $this = shift;
  my $p1 = shift;
  my $r1 = shift;
  my $r0 = $r1 - 1;
  my $p1id = $p1->ID();
  my $p2id = $p1->OpponentID($r0);
  my $p2 = $p1->Opponent($r0);
  my $config = $p1->Division()->Tournament()->Config();
  my $start_time = $config->Value('start_times')->[$r0];

  if (!defined $p2id) { return; } # unpaired

  my $p1record = sprintf("%d-%d %+d", $p1->Wins(), $p1->Losses(), $p1->Spread());

  if (!$p2id) { # bye
    $p1->TweetDM("#TSH #Scrabble: You are $p1record. Rd $r1 starts $start_time, but you have a bye.") if defined $p1->TwitterName();
    return;
    }

  my $p2record = sprintf("%d-%d %+d", $p2->Wins(), $p2->Losses(), $p2->Spread());

  my $location1 = $p1->RenderLocation($r0);
  $location1 = (defined $location1) ? " at $location1" : '';
  my $location2 = $p2->RenderLocation($r0); # could be different with seats
  $location2 = (defined $location2) ? " at $location2" : '';

  my $p121 = $p1->First($r0);
  $p121 = ('?!', 'go 1st', 'go 2nd', 'draw for 1st', 'play')[$p121];
  my $p122 = $p2->First($r0);
  $p122 = ('?!', 'go 1st', 'go 2nd', 'draw for 1st', 'play')[$p122];

  my $p1name = $p1->TwitterName();
  $p1name = (defined $p1name) ? '@' . $p1name : $p1->PrettyName({'surname_last'=>1});
  my $p2name = $p2->TwitterName();
  $p2name = (defined $p2name) ? '@' . $p2name : $p2->PrettyName({'surname_last'=>1});

  $p1->TweetDM("#TSH #Scrabble: You're $p1record. Rd$r1 starts $start_time. You $p121$location1 vs #$p2id $p2name.") if defined $p1->TwitterName();
  $p2->TweetDM("#TSH #Scrabble: You're $p2record. Rd$r1 starts $start_time. You $p122$location2 vs #$p1id $p1name.") if defined $p2->TwitterName();
  }

=item $command->Run($tournament, @parsed_args)

Should run the command in the context of the given
tournament with the specified parsed arguments.

=cut

# TODO: split this up into smaller subs for maintainability

sub Run ($$@) { 
  my $this = shift;
  my $tournament = shift;
  my ($round, $dp) = @_;
  my $config = $tournament->Config();
  my $round0 = $round - 1;

  for my $required (qw(start_times twitter_dm_command)) {
    unless (defined $config->Value($required)) {
      $tournament->TellUser('ecfgreq', $required);
      return 0;
      }
    }

  if ($round0 > $dp->LastPairedRound0()) {
    $tournament->TellUser('enopryet', $dp->Name(), $round);
    return;
    }

  for my $p ($dp->Players()) {
    next if ($p->OpponentID($round0) || 0) > $p->ID();
    $this->TweetPair($p, $round);
    }
  }

=back

=cut

=head1 BUGS

For larger tournaments, should post to FB or use Twitter status updates to avoid
reaching posting limit.

=cut

1;

