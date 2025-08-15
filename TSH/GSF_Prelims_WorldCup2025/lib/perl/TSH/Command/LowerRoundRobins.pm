#!/usr/bin/perl

# Copyright (C) 2008 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::LowerRoundRobins;

use strict;
use warnings;

use TSH::PairingCommand;
use TSH::Utility;
# use TSH::Division::Pairing::Clark;
use TSH::Division::Pairing::Berger;

our (@ISA) = qw(TSH::PairingCommand);
our @Pairings;
our @Starts;

=pod

=head1 NAME

TSH::Command::LowerRoundRobins - implement the C<tsh> LowerRoundRobins command

=head1 SYNOPSIS

  my $command = new TSH::Command::LowerRoundRobins;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::LowerRoundRobins is a subclass of TSH::PairingCommand.

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
Use the LowerRoundRobins command to manually add grouped round robin pairings 
to the bottom of a division.  Specify the rank beginning at which you want
the round robins to start, the number of rounds you want them to continue,
and the division to be paired.  Before you use this command, think 
carefully about using Fontes Swiss or Chew pairings instead.
LowerRoundRobins pairings are a bad idea because they may have to give
extra byes to undeserving players, if there is a tie at the
rank threshold, it will have to be broken randomly, and of course because
the staleness of the pairings will lead to the wrong players playing each other.
EOF
  $this->{'names'} = [qw(lrr lowerroundrobins)];
  $this->{'argtypes'} = [qw(Rank NumberOfRounds Division)];
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
  my $first_rank = shift;
  my $nrounds = shift;
  my $dp = shift;
  my $config = $tournament->Config();

  my $datap = $dp->{'data'};

  unless ($nrounds % 2) { 
    $tournament->TellUser('elrrnotodd', $nrounds);
    return 0;
    }

  my $last_scored_round0 = $dp->MostScores() - 1;
  $dp->ComputeRanks($last_scored_round0);
  my (@players) = $dp->Players();
  TSH::Player::SpliceInactive @players, 1, $last_scored_round0;
  @players = TSH::Player::SortByCurrentStanding @players;
  splice(@players, 0, $first_rank-1);
  unless (@players) {
    $tournament->TellUser('ealpaird', $last_scored_round0+1); # all paired
    return;
    }

  my $last_paired_round0 = $players[0]->CountOpponents()-1;
  for my $p (@players[1..$#players]) {
    my $r0 = $p->CountOpponents()-1;
    if ($r0 != $last_paired_round0) {
      $tournament->TellUser('errpartp');
      return;
      }
    }

  # assign players to groups
  my @groups;
  if (@players == 2*$nrounds) {
    (@groups) = ([@players[0..$nrounds-1]], [@players[$nrounds..$#players]]);
    }
  else {
    while (@players >= 2*$nrounds + 1) {
      push(@groups, [splice(@players, 0, $nrounds+1)]);
      }
    if (@players) { 
      push(@groups, \@players);
      }
    }

  if ($config->Value('random_rr_order')) {
    # Knuth shuffle
    for my $groupp (@groups) {
      my $n = scalar(@$groupp);
      while (--$n > 0) {
	my $k = int(rand()*($n+1));
	@$groupp[$n,$k] = @$groupp[$k,$n];
	}
      }
    }

  TSH::Division::Pairing::Berger::PairGroups(\@groups, $nrounds);

  $tournament->TellUser('idone');

  $dp->Dirty(1);
  $this->Processor()->Flush();
  }

=cut

=head1 BUGS

None known.

=cut

1;
