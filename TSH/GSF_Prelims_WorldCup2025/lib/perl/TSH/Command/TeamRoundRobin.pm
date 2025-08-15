#!/usr/bin/perl

# Copyright (C) 2008 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::TeamRoundRobin;

use strict;
use warnings;

use TSH::PairingCommand;
use TSH::Utility;
use TSH::Division::Team;
use TSH::Division::Pairing::Berger;

our (@ISA) = qw(TSH::PairingCommand);
our @Pairings;
our @Starts;

=pod

=head1 NAME

TSH::Command::TeamRoundRobin - implement the C<tsh> TeamRoundRobin command

=head1 SYNOPSIS

  my $command = new TSH::Command::TeamRoundRobin;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::TeamRoundRobin is a subclass of TSH::PairingCommand.

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
Use the TeamRoundRobin command to manually add a set of full team 
"round robin" pairings
to a division, where each player plays every player on every other
team.  
If the last paired round is only partially paired, the round robins 
will be constructed using the players left unpaired in that round;
otherwise the full division will be paired.
If you specify an integer before the
division name, each pairing will be repeated that number of times.
EOF
  $this->{'names'} = [qw(trr teamroundrobin)];
  $this->{'argtypes'} = [qw(OptionalInteger Division)];
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
  my $dp = pop @_;
  my $count = @_ ? pop @_ : 1;
  $this->{'trr_tournament'} = $tournament;

  my $round0 = $dp->FirstUnpairedRound0();
  my $psp = $dp->GetUnpairedRound($round0);
  my $teamhashp = TSH::Division::Team::GroupByTeam($psp);
  my @teams = map { $teamhashp->{$_} } sort keys %$teamhashp;
  if (@teams < 2) {
    $tournament->TellUser('etrrsmall');
    return;
    }
  my $team_size = scalar(@{$teams[0]});
  my $min_team_size = $team_size;
  for my $a_team (@teams[1..$#teams]) {
    my $a_team_size = scalar(@$a_team);
    if ($a_team_size < $min_team_size) { $min_team_size = $a_team_size; }
    if ($a_team_size > $team_size) { $team_size = $a_team_size; }
    }
  if ($team_size - $min_team_size > 1) {
    $tournament->TellUser('etrruneven');
    return;
    }
  my $success = @teams % 2 
    ? $this->PairOddTeams(\@teams, $count, $round0, $team_size, $min_team_size)
    : $this->PairEvenTeams(\@teams, $count, $round0, $team_size, $min_team_size);

  if ($success) {
    $tournament->TellUser('idone');
    $dp->Dirty(1);
    $this->Processor()->Flush();
    }
  }

sub PairEvenTeams ($$$$$$) {
  my $this = shift;
  my $teamsp = shift;
  my $count = shift;
  my $round0 = shift;
  my $team_size = shift;
  my $min_team_size = shift;
  my $swap = int(rand(2));
  my $dp = $teamsp->[0][0]->Division();
  my $tournament = $dp->Tournament();
  my (@sorted_teams) = map { [ TSH::Player::SortByInitialStanding @$_ ] } @$teamsp;
# warn "Team 0: " . join(';', map { $_->Name() } @{$teamsp->[0]});
  $tournament->TellUser('itrrok', $dp->{'name'});
  my $nteams = scalar(@sorted_teams);
  my $config = $tournament->Config();
  my $config_order = $config->Value('round_robin_order');
  my $random = $config_order ? 0 : $config->Value('random') > 0.5;

  # iterate over schedule phase
  # - in each phase, each member of one team will play each member of an assigned opposing team
  for my $phase (1..$nteams-1) {
    # compute which teams play which teams using the Berger Round Robin algorithm
    my (@table) = @{TSH::Division::Pairing::Berger::ComputeBergerRound({
      'assign_firsts' => 1,
      'first_opponent' => $nteams - $phase + 1,
      'player_count' => $nteams,
      'random' => $random,
      })};
    # @table looks like (p1, p2, p3, ..., opp3, opp2, opp1)
    my $swap;
    while (@table) {
      # get next player and opponent
      my (@t) = map { $sorted_teams[$_-1] } (shift @table, pop @table);
      # swap them in even rounds to effect balanced starts/replies
      if (defined $swap) { 
	$swap = 1 - $swap; 
	if ($swap) { @t[0,1] = @t[1,0]; }
	}
      else { $swap = 1; }
      # pair two teams so that everyone plays everyone on the opposing team
      $this->PairTwoTeams({
	'dp' => $dp,
	'team1' => $t[0],
	'team2' => $t[1],
	'team_size' => $team_size,
	'round0' => $round0 + ($phase-1) * $team_size,
	'count' => $count,
	});
      }
    }
  return 1;
  }

# The case where we have an odd number of teams is problematic, and we have not yet
# tested a general solution.  For 5 teams of 3 players, here is an algorithm provided
# at WESPAC2017 by Adam Logan.
#
# Observe first that we have 15 players, each of whom play 12 opponents, for a total
# of 90 games. Each round can have at most 7 games played, plus a bye. 90=12*7+6,
# so we need at least 13 rounds, consisting of 12 rounds with one bye and 1 round with
# three byes.
#
# Given the availability of a tool for completing Latin squares (util/make-rr.pl),
# we configure it as follows:
# my $n = 16;
# my (@table) = (
# [0..15],
# [1,0,5,4,3,2,7,6,11,10,9,8,13,12,15,14],
# [2,4,0,5,1,3,8,10,6,11,7,9,14,15,12,13],
# [3,2,1,0,5,4,9,8,7,6,11,10,15,14,13,12],
# );
# indicating a round robin of sixteen players, numbered starting at 0: A1 A2 A3
# B1 B2 B3 ... E1 E2 E3 bye.  The first row (0..15) prevents players from playing
# themselves, the next prevents X1-X2, the next X1-X3, the last X2-X3.  The utility
# then provides the following schedule:
#
#  1  2  3  4 12  5 10  7 14 11 16 15  8  9 13  6
#  2  1  5  3 10 12 11 14  7 15  6 16 13  8  4  9
#  3  6  1  2 13  9  4  8 15 16 11  7 14  5 12 10
#  4  5  6  1 14  7  3 11 10 12  8  9 16 15  2 13
#  5  4  2  6 11  1 12 10 16  7 14 13 15  3  9  8
#  6  3  4  5  7 14 15 13  9  8  2 12 10 11 16  1
#  7  8  9 10  6  4 16  1  2  5 15  3 12 13 11 14
#  8  7 11  9 16 13 14  3 12  6  4 10  1  2 15  5
#  9 12  7  8 15  3 13 16  6 14 10  4 11  1  5  2
# 10 11 12  7  2 15  1  5  4 13  9  8  6 16 14  3
# 11 10  8 12  5 16  2  4 13  1  3 14  9  6  7 15
# 12  9 10 11  1  2  5 15  8  4 13  6  7 14  3 16
# 13 14 15 16  3  8  9  6 11 10 12  5  2  7  1  4
# 14 13 16 15  4  6  8  2  1  9  5 11  3 12 10  7
# 15 16 13 14  9 10  6 12  3  2  7  1  5  4  8 11
# 16 15 14 13  8 11  7  9  5  3  1  2  4 10  6 12
#
# from which we omit the first three rounds, combining the 2 legal pairs in each
# to make a 13th round where An-Bn, Cn-Dn, and En-bye, resulting in the table
# in the here document below


sub PairOddTeams ($$$$$$) {
  my $this = shift;
  my $teamsp = shift;
  my $count = shift;
  my $round0 = shift;
  my $team_size = shift;
  my $min_team_size = shift;
  my $dp = $teamsp->[0][0]->Division();
  my $tournament = $dp->Tournament();
  if ($min_team_size != 3 or $team_size != 3 or @$teamsp != 5) {
    $tournament->TellUser('etrrunodd');
    return 0;
    }
  my (@sched) = (map {
    s/^\s*//; s/\s*$//;
    [split(/\s+/, $_)];
    } split(/\n/, <<'EOS'));
12  5 10  7 14 11  0 15  8  9 13  6  4
10 12 11 14  7 15  6  0 13  8  4  9  5
13  9  4  8 15  0 11  7 14  5 12 10  6
14  7  3 11 10 12  8  9  0 15  2 13  1
11  1 12 10  0  7 14 13 15  3  9  8  2
 7 14 15 13  9  8  2 12 10 11  0  1  3
 6  4  0  1  2  5 15  3 12 13 11 14 10
 0 13 14  3 12  6  4 10  1  2 15  5 11
15  3 13  0  6 14 10  4 11  1  5  2 12
 2 15  1  5  4 13  9  8  6  0 14  3  7
 5  0  2  4 13  1  3 14  9  6  7 15  8
 1  2  5 15  8  4 13  6  7 14  3  0  9
 3  8  9  6 11 10 12  5  2  7  1  4  0
 4  6  8  2  1  9  5 11  3 12 10  7  0
 9 10  6 12  3  2  7  1  5  4  8 11  0
EOS
  my (@players) = map { @$_ } @$teamsp;
  for my $round_offset (0..$#{$sched[0]}) {
    for my $i (0..$#players) {
      my $oi1 = $sched[$i][$round_offset];
      next if $oi1 > $i+1;
      $dp->Pair($players[$i]->ID(),
	$oi1 ? $players[$oi1-1]->ID() : 0,
	$round0 + $round_offset);
#     warn (($i+1).'-'.($oi1));
      }
    }
  return 1;
  }

sub PairTwoTeams ($$) {
  my $this = shift;
  my $optionsp = shift;
  my $count = $optionsp->{'count'};
  my $dp = $optionsp->{'dp'};
  my $round0 = $optionsp->{'round0'};
  my $team1p = $optionsp->{'team1'};
  my $team2p = $optionsp->{'team2'};
  my $team_size = $optionsp->{'team_size'};
# warn join(' ', map { $_->{'id'} } @$team1p);
# warn join(' ', map { $_->{'id'} } @$team2p);
  my $config = $this->{'trr_tournament'}->Config();
  my $config_order = $config->Value('round_robin_order');
  if (my $order = ($config_order && (@$config_order == 2 * $team_size))) {
#   warn "Reordering team players as per config round_robin_order: @$config_order.\n";
#   warn "Before: " . join('; ', map { $_ && $_->Name() } @$team1p) . '. ' . join('; ', map { $_->Name() } @$team2p) . '.';
    $team1p = [grep { defined $_ } @$team1p[map { $_-1 } @$config_order[0..$team_size-1]]];
    $team2p = [grep { defined $_ } @$team2p[map { $_-1 } @$config_order[$team_size..2*$team_size-1]]];
#   warn "After: " . join('; ', map { $_ && $_->Name() } @$team1p) . '. ' . join('; ', map { $_->Name() } @$team2p) . '.';
    }
  for my $i (0..$team_size-1) {
    for my $k (1..$count) {
      for my $j (0..$team_size-1) {
	my $p1 = $team1p->[$j];
	my $p2 = $team2p->[($team_size*2-1-$i+$j) % $team_size];
        my $pn1 = $p1 ? $p1->ID() : 0;
        my $pn2 = $p2 ? $p2->ID() : 0;
#	warn "$i;$k;$j;$pn1;$pn2";
	$dp->Pair($pn1, $pn2, $round0, 0);
        }
      $dp->GetUnpairedRound($round0++); # side-effect: assign byes to inactive players
      }
    }
  }

=back

=cut

=head1 BUGS

- T teams, P players per team
- (T-1)*P rounds
- in each P-round phase, two teams are chosen from a team RR schedule, and all their players face each other
- if T is odd, split teams in half, each team plays two others from consecutive RR schedules

- will pair past max_rounds!

None known.

=cut

1;
