#!/usr/bin/perl

# Copyright (C) 2018 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::Division::Pairing::Bracket;

use strict;
use warnings;

use TSH::Utility qw(Debug IsASafely Min);

our(@ISA) = 'Exporter';
our(@EXPORT_OK) = qw(
  DumpBracket
  GetSchedule
  MakeBracket
  MakePhaseStartRound0s
  ZeroOutPartials
  );

=pod

=head1 NAME

TSH::Division::Pairing::Bracket - code to support bracket-style pairings

=head1 SYNOPSIS

  TSH::Division::Pairing::Clark::PairGroup(\@players, $opp1, \%options);

=head1 ABSTRACT

This module provides utility functions used in bracket (single-elimination)
pairings.

=cut

sub ComparePhaseRecords ($$$$);
sub DumpBracket ($);

=head1 DESCRIPTION

=over 4

=cut
 
=item $comparison = ComparePhaseRecords($p1, $p2, \@phaseStarts, $phi);

Return -1, 0 or 1 according to how C<$p1> and C<$p2> records compare
over the 0-indexed C<$phi>th phase as given by C<@phaseStarts>.

=cut

sub ComparePhaseRecords ($$$$) {
  my $p1 = shift;
  my $p2 = shift;
  my $phaseStartRound0sp = shift;
  my $phi = shift;
  
  my $first_r0 = $phaseStartRound0sp->[$phi] - 1;
  my $last_r0  = $phaseStartRound0sp->[$phi+1] - 1;
# warn "first_r0=$first_r0 last_r0=$last_r0";

  return 
    (
      ( $p1->RoundWins($last_r0) - $p1->RoundWins($first_r0) )
	<=>
      ( $p2->RoundWins($last_r0) - $p2->RoundWins($first_r0) )
	||
      ( $p1->RoundSpread($last_r0) - $p1->RoundSpread($first_r0) )
	<=>
      ( $p2->RoundSpread($last_r0) - $p2->RoundSpread($first_r0) )
    );
  }

=item $s = DumpBracket($);

Return a more or less human-readable version of a bracket, 
for debugging purposes.

=cut

sub DumpBracket ($) {
  my $bracket = shift;

  my ($seed, $p, $n1, $n2) = @$bracket;
  my $s = "[$seed: ";
  if ($p) { $s .= $p->TaggedName(); }
  else { $s .= 'null'; }
  $s .= ': ';
  if ($n1) { $s .= DumpBracket $n1; }
  else { $s .= 'null'; }
  $s .= ' vs ';
  if ($n2) { $s .= DumpBracket $n2; }
  else { $s .= 'null'; }
  $s .= ']';
  return $s;
  }

=item $schedulep = GetSchedule($nplayers);

Return a pairing schedule for C<$nplayers> players.

A pairing schedule is a reference to a list of numbers in the range
C<0..$nplayers>.  Each consecutive pair indicates a pair of indices
of players who should be paired with each other, with C<0> indicating
a bye.

After assigning byes as needed to fill a power of two, the remaining
players will be paired matching the top player with the bottom player
repeatedly.

=cut

sub GetSchedule ($) {
  my $nplayers = shift;
  die "$nplayers is not a positive number" if $nplayers !~ /^\d+$/;
  my $power2 = 1;
  while ($power2 < $nplayers) {
    $power2 += $power2;
    }
  my $nbyes = $power2 - $nplayers;
  my @schedule;
  for my $i (1..$nbyes) {
    push(@schedule, $i, 0);
    }
  for (my ($i, $j) = ($nbyes+1, $nplayers); $i < $j; $i++, $j--) {
    push(@schedule, $i, $j);
    }
  return \@schedule;
  }

=item $bracketp = MakeBracket(\@ps);

Return a pointer to a tree structure describing the pairings
assigned or to be assigned for a group of players who have
already been assigned at least their initial bracket seeds.

=cut

sub MakeBracket($) {
  my $psp = shift;
  my $dp = $psp->[0]->Division();
  my $config = $dp->Tournament()->Config();
  my (@phaseStartRound0s) = @{MakePhaseStartRound0s($dp)};
  
# die "@phaseStartRound0s";
  my @playerPhaseInfo;
  my @pidToIndex;

  for my $pi (0..$#$psp) {
    my $p = $psp->[$pi];
    $pidToIndex[$p->ID()] = $pi;
    my $seeds = $p->GetOrSetEtcVector('bracketseed');
    unless ($seeds) {
      warn "Cannot make bracket before initial bracket seeds are set";
      return undef;
      }
    for my $phi (0..$#phaseStartRound0s) {
      $playerPhaseInfo[$pi][$phi] = { 
	'opp' => $p->Opponent($phaseStartRound0s[$phi]),
	'seed' => $seeds->[$phi],
	};
      }
    }

  # Use first-phase info to build the leaves of the bracket
  #
  # @bracket is a list of rightmost (chronologically last) nodes.
  # A node is a reference to a list containing the following elements
  # - bracket seed in current phase
  # - player occupying this slot if any
  # - reference to upper child if any
  # - reference to lower child if any
  my (@bracket);
  for my $pi (0..$#$psp) {
    my $p = $psp->[$pi];
    my $ppinfo = $playerPhaseInfo[$pi];
    push(@bracket, [$ppinfo->[0]{'seed'}, $p]);
    }
# warn join(', ', map { '['.($_->[0]//'undef').',' . $_->[1]->ID() . ',' . ($_->[2]//'null') . ',' . ($_->[3] // 'null') . ']' } @bracket);

  my $phi = 0;
  # while the bracket still has two branches and we still have phases
  while ($phi <= $#phaseStartRound0s and @bracket > 1) {
    my (@seedToNode, @idToNode, @newBracket, %seenId);
    for my $node (@bracket) { 
      $seedToNode[$node->[0]] = $node; 
      $idToNode[$node->[1]->ID()] = $node if $node->[1];
      }
     # Use pairing information if present? 
     # This seemed like a good idea early on, in case a director had to manually override
     # something, but it would probably be better for them to tweak the bracketseeds.
     # Leaving the code in place though, just in case a use case pops up.
    if (0 and $bracket[0][1] and defined $bracket[0][1]->OpponentID($phaseStartRound0s[$phi])) {
      warn "phase $phi: " . scalar(@bracket) . " top nodes left, using pairing info";
      for my $node (@bracket) {
	my $p = $node->[1];
	next unless $p;
	next if $seenId{$p->ID()}++;
#	warn "$p->{id} was not yet seen";
	my $ppinfo = $playerPhaseInfo[$pidToIndex[$p->ID()]];
	my $pseed = $ppinfo->[$phi]{'seed'}  || $node->[0];
	if (my $opp = $p->Opponent($phaseStartRound0s[$phi])) {
	  my $oid = $opp->ID();
	  $seenId{$oid}++;
#	  warn "marking $oid as seen";
	  my $oppinfo = $playerPhaseInfo[$pidToIndex[$oid]];
	  my $onode = $idToNode[$oid];
	  my $oseed = $oppinfo->[$phi]{'seed'} || $onode->[0];
#	  warn "s$pseed#$p->{'id'} vs s$oseed#$oid" if $phi >= 1;
          my $newseed = Min($pseed, $oseed);
	  my $p1 = $p;
	  my $p2 = $opp;
	  my $n1 = $node;
	  my $n2 = $onode;
#	  warn "no oseed for #$p->{'id'}" unless defined $oseed;
	  # if there is an even seed and an odd seed 
	  if (($pseed+$oseed) % 2) {
	    # then the odd seed is first
	    if ($oseed % 2) {
	      ($p1, $p2) = ($p2, $p1);
	      ($n1, $n2) = ($n2, $n1);
	      }
	    }
          my $which = 0;
	  $which = ComparePhaseRecords(
	    $p1, $p2, \@phaseStartRound0s, $phi);
#	  warn "$phi #$p1->{id} vs #$p2->{id} which=$which";
          push(@newBracket, [
            $newseed,
	    (undef, $p1, $p2)[$which],
            $n1, $n2,
            ]);
	  }
	else {
	  push(@newBracket, [$pseed, $p, $node ]);
	  }
        }
      }
     # else use a standard schedule
    else {
#     warn "phase $phi: " . scalar(@bracket) . " top nodes left, using fixed schedule";
      my $sched = GetSchedule(scalar(@bracket));
      while (@$sched) {
        my $p1seed = shift @$sched;
        my $p2seed = shift @$sched;
        my $n1 = $seedToNode[$p1seed];
        my $n2 = $seedToNode[$p2seed];
#	warn "n1=[@$n1] n2=[@$n2]";
        if ($p2seed) {
          my $which = 0;
          if (IsASafely($n1->[1], 'TSH::Player')
	    and IsASafely($n2->[1], 'TSH::Player')) {
            $which = ComparePhaseRecords(
	      $n1->[1], $n2->[1], \@phaseStartRound0s, $phi);
            }
#	  warn "$phi #$n1->[1]{id} vs #$n2->[1]{id} which=$which";
          push(@newBracket, [Min($p1seed, $p2seed),
	    (undef, $n1->[1], $n2->[1])[$which],
            $n1, $n2]);
          }
        else {
          push(@newBracket, [$p1seed, $n1->[1], $n1]);
          }
        }
       }
     (@bracket) = (@newBracket);
# warn join(', ', map { '['.($_->[0]//'undef').',' . ($_->[1] ? $_->[1]->ID() : 'null') . ',' . ($_->[2]//'null') . ',' . ($_->[3] // 'null') . ']' } @bracket);
     $phi++;
     }

  return $bracket[0];
  }

=item $phaseStartRound0sp = MakePhaseStartRound0s($dp);

Return a pointer to a list of 0-based round numbers of the start
of each bracket phase.

=cut

sub MakePhaseStartRound0s($) {
  my $dp = shift;

  my $max_round0 = $dp->MaxRound0();
  my $phase_lengths_p = $dp->GetConfigValue('bracket_repeats') || [1];
  $phase_lengths_p = [$phase_lengths_p] if ref($phase_lengths_p) eq '';
  
  my (@phaseStartRound0s) = ($dp->GetConfigValue('bracket_prelims') || 0);
  while ($phaseStartRound0s[-1] < $max_round0) {
    my $phase_length = @$phase_lengths_p > 1 
      ? shift @$phase_lengths_p : $phase_lengths_p->[0];
    push(@phaseStartRound0s, $phaseStartRound0s[-1] + $phase_length);
    }

  return \@phaseStartRound0s;
  }

=item $changed = ZeroOutPartials($dp);

If the outcome of any pairing has been determined, but now unnecessary
games are still scheduled to be played, 

=cut

sub ZeroOutPartials ($) {
  my $dp = shift;
  my $prelims = $dp->GetConfigValue('bracket_prelims');
  my $maxr0 = $dp->MaxRound0();
  my (@phaseStartRound0s) = (@{MakePhaseStartRound0s($dp)}, $maxr0+1);
  my $changed = 0;
  
  for my $p ($dp->Players()) {
#   warn "ZOP: checking $p->{name} #$p->{id}";
    # find the first round where a player has no score
    my $r0 = 0;
    while ((defined $p->Score($r0)) and $r0 <= $maxr0) { $r0++ }
    # continue with next player if player has scores in all rounds
    next if $r0 > $maxr0;
    # continue with next player if player has neither score nor paired opponent in this round
    next unless $p->Opponent($r0);
    # continue with next player if this round is during the prelims
    next if $r0 < $prelims;
    # else player is scheduled to play someone during a bracket but has not yet done so
    # find first and last rounds in phase
    # TODO: this is not the only place in which we find the first and last rounds in a phase; combine
    my $first0 = 0;
    my $last0 = -1;
    my $phi = -1;
    while (($first0 > $r0 or $r0 > $last0) and $phi < $#phaseStartRound0s) {
      $phi++;
      $first0 = $phaseStartRound0s[$phi];
      $last0 = $phaseStartRound0s[$phi+1] - 1;
      }
#   next if $phi >= $#phaseStartRound0s; # should never happen
    my $wins   = $p->RoundWins($last0) - $p->RoundWins($first0-1);
    my $losses = $p->RoundLosses($last0) - $p->RoundLosses($first0-1);
    my $rounds = $last0 - $first0;
    # continue with next player if this player has clinched neither a phase win nor loss
    next unless ($wins<<1) > $rounds or ($losses<<1) > $rounds;
#   if (($wins<<1) > $rounds) { warn "$p->{name} has clinched rounds @{[$first0+1]}-@{[$last0+1]}" } else { warn "$p->{name} has already been eliminated for rounds @{[$first0+1]}-@{[$last0+1]}" } 
    for my $i0 ($r0..$last0) {
      if (my $opp = $p->Opponent($i0)) {
#	warn "zeroing $p->{name} #$p->{id} and $opp->{name} #$opp->{id} in round @{[$i0+1]}";
	$opp->Score($i0, 0);
	$dp->Pair($opp->ID(), 0, $i0, 1);
        }
      $p->Score($i0, 0);
      $dp->Pair($p->ID(), 0, $i0, 1);
      $changed++;
      }
    }
  return $changed;
  }

=back

=cut

1;
