#!/usr/bin/perl

# Copyright (C) 2011 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::TeamMultipleRoundRobin;

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

TSH::Command::TeamMultipleRoundRobin - implement the C<tsh> TeamMultipleRoundRobin command

=head1 SYNOPSIS

  my $command = new TSH::Command::TeamMultipleRoundRobin;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::TeamMultipleRoundRobin is a subclass of TSH::PairingCommand.

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
Use the TeamMultipleRoundRobin command to add a set of full team 
"multiple round robin" pairings to a division, where the members
of each team are divided into squads according to their standing in the 
designated round, then play each player on every corresponding
opposing squad.
If the last paired round is only partially paired, the round robins 
will be constructed using the players left unpaired in that round;
otherwise the full division will be paired.
You must specify the number of times you would like each pairing
to be repeated, and the number of different opponents you would
like each player to play.
EOF
  $this->{'names'} = [qw(tmrr teammultipleroundrobin)];
  $this->{'argtypes'} = [qw(Repeats NumberOfRounds Division)];
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
  my $nr = pop @_;
  my $count = @_ ? pop @_ : 1;
# if ($nr % 2 == 0) {
#   $tournament->TellUser('egrreven', $nr);
#   return 0;
#   }
  $this->{'tmrr_nr'} = $nr;

  my $round0 = $dp->FirstUnpairedRound0();
  my $psp = $dp->GetUnpairedRound($round0);
  my $teamhashp = TSH::Division::Team::GroupByTeam($psp);
  my @teams = map { $teamhashp->{$_} } sort keys %$teamhashp;
  if (@teams < 2) {
    $tournament->TellUser('etrrsmall');
    return 0;
    }
  my $team_size = scalar(@{$teams[0]});
  my $min_team_size = $team_size;
  my $squad_size = $nr;
  if ($team_size % $squad_size) {
    $tournament->TellUser('etmrrmod');
    return 0;
    }
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
  my (@sorted_teams) = map { [ TSH::Player::SortByCurrentStanding @$_ ] } @$teamsp;
  $tournament->TellUser('itrrok', $dp->{'name'});
  my $nteams = scalar(@sorted_teams);
  my $random = $tournament->Config()->Value('random') > 0.5;

  for my $phase (1..$nteams-1) {
    my (@table) = @{TSH::Division::Pairing::Berger::ComputeBergerRound({
      'assign_firsts' => 1,
      'first_opponent' => $nteams - $phase + 1,
      'player_count' => $nteams,
      'random' => $random,
      })};
    my $swap;
    while (@table) {
      my (@t) = map { $sorted_teams[$_-1] } (shift @table, pop @table);
      if (defined $swap) { 
	$swap = 1 - $swap; 
	if ($swap) { @t[0,1] = @t[1,0]; }
	}
      else { $swap = 1; }
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

sub PairOddTeams ($$$$$$) {
  my $this = shift;
  my $teamsp = shift;
  my $count = shift;
  my $round0 = shift;
  my $team_size = shift;
  my $min_team_size = shift;
  my $tournament = $teamsp->[0][0]->Division()->Tournament();
  $tournament->TellUser('etrrunodd');
  return 0;
  }

sub PairTwoTeams ($$) {
  my $this = shift;
  my $optionsp = shift;
  my $count = $optionsp->{'count'};
  my $dp = $optionsp->{'dp'};
  my $team1p = $optionsp->{'team1'};
  my $team2p = $optionsp->{'team2'};
  my $team_size = $optionsp->{'team_size'};
# warn join(' ', map { $_->{'id'} } @$team1p);
# warn join(' ', map { $_->{'id'} } @$team2p);
  my $squad_size = $this->{'tmrr_nr'};
  for (my $offset = 0; $offset < $team_size; $offset += $squad_size) {
#   warn "offset=$offset";
    my $round0 = $optionsp->{'round0'};
    for my $i (0..$squad_size-1) {
      for my $k (1..$count) {
	for my $j (0..$squad_size-1) {
	  my $p1 = $team1p->[$offset + $j];
	  my $p2 = $team2p->[$offset + (($squad_size*2-1-$i+$j) % $squad_size)];
	  my $pn1 = $p1 ? $p1->ID() : 0;
	  my $pn2 = $p2 ? $p2->ID() : 0;
#	  warn "$pn1 $pn2 $round0";
	  $dp->Pair($pn1, $pn2, $round0, 0);
	  }
	$dp->GetUnpairedRound($round0++); # side-effect: assign byes to inactive players
	}
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

None known.

=cut

1;
