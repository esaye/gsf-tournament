#!/usr/bin/perl

# Copyright (C) 2005-2007 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package ABSP;

use strict;
use warnings;

use TSH::Utility qw(Debug);

=pod

=head1 NAME

ABSP - Association of British Scrabble Players support class

=head1 SYNOPSIS

  use ABSP;
  my @players = (undef, 
    { 'rating' => 150, 'scores' => [400, 450,  50], 'pairings' => [2, 3, 0] },
    { 'rating' => 140, 'scores' => [350,  50, 350], 'pairings' => [1, 0, 3] },
    { 'rating' => 130, 'scores' => [ 50, 300, 300], 'pairings' => [0, 1, 2] },
    );
  ABSP::CalculateRatings(@players);
  print "Player #1's new rating: $players[1]{'newr'}\n";

  
=head1 ABSTRACT

This Perl library provides support for ABSP-related calculations.

=head1 DESCRIPTION

=over 4

=cut

sub CalculateRating($\@$$);
sub CalculateRatings($\@);

=item ABSP::CalculateRating($maxr0, @players, $player_number, $phase)

Updates one player's rating, called by CalculateRatings.
In Phase 1, unrated player ratings are estimated.
In Phase 2, unrated player ratings are recalculated using Phase 1 ratings.
In Phase 3, rated player ratings are updated.

=cut

sub CalculateRating($\@$$) {
  my $maxr0 = shift;
  my $datap = shift;
  my $id = shift;
  my $phase = shift;
  my $p = $datap->[$id];
  my $mr = $p->Rating();
  my $newr = 0;
  my $ngames = 0;
  my $debug = '(';
  my $this_maxr0 = $#{$p->{'scores'}};
  $this_maxr0 = $maxr0 if $this_maxr0 > $maxr0;
  return unless $this_maxr0 >= 0;
  for my $r0 (0..$this_maxr0) {
    my $oppid = $p->{'pairings'}[$r0];
    next unless $oppid;
    my $opp = $datap->[$oppid];
    my $ms = $p->{'scores'}[$r0];
    next unless $ms;
    my $os = $opp->{'scores'}[$r0];
    next unless $os;
    my $oppr;
    if ($phase == 1) {
      $oppr = $opp->Rating();
      }
    elsif ($phase == 2) {
      $oppr = $opp->Rating() || $opp->{'tmpr'};
      }
    elsif ($phase == 3) {
      $oppr = $opp->Rating() || $opp->{'newr'};
      }
    next unless $oppr;
    $ngames++;
    if ($mr) {
      if ($opp->Rating()) {
	  if ($oppr > $mr + 40) { $oppr = $mr + 40; }
	  elsif ($oppr < $mr - 40) { $oppr = $mr - 40; }
	}
      # TODO: implement novice ratings enhancement: a player cannot
      # have an effective rating of below 80 until they have finished
      # playing the tournament containing their 15th game.
      }
    $newr += $oppr;
    $debug .= "+$oppr";
    my $result = 50 * ($ms <=> $os);
    $newr += $result;
    $debug .= sprintf("%+d", $result);
    }
  $debug .= ")/$ngames.";
  if ($ngames) {
    $newr /= $ngames;
    }
  else {
    $newr = $mr;
    $debug .= " Set to 0."
    }
  if ($p->Rating()) {
    if ($newr < 40) { 
      $newr = 40; 
      $debug .= " Capped at 40."
      }
    }
  else {
    if ($newr < 80) { 
      $newr = 80; 
      $debug .= " Capped at 80."
      }
    }

  $newr = int($newr + 0.5);
  if ($phase == 1) {
    $p->{'tmpr'} = $newr;
    }
  else {
    $p->NewRating($this_maxr0, $newr);
    $debug =~ s/\(\+/(/;
    Debug('ABSP', "%d: %s New rating is %d.", $p->ID(), $debug, $newr);
    }
  }

=item ABSP::CalculateRatings($r0, @players)

Updates a list of hashes of player information to include tournament ratings.

=cut

sub CalculateRatings($\@) {
  my $r0 = shift;
  my $datap = shift;

  # calculate initial ratings for unrated players
  for my $id (1..$#$datap) {
    CalculateRating $r0, @$datap, $id, 1 unless $datap->[$id]->Rating();
    }
  # calculate final ratings for unrated players
  for my $id (1..$#$datap) {
    CalculateRating $r0, @$datap, $id, 2 unless $datap->[$id]->Rating();
    }
  # calculate initial ratings for previously rated players
  for my $id (1..$#$datap) {
    CalculateRating $r0, @$datap, $id, 3 if $datap->[$id]->Rating();
    }
  }

=back

=cut

1;
