#!/usr/bin/perl

# Copyright (C) 2010 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package Sudoku;

use strict;
use warnings;

use TSH::Utility qw(Debug);
use Ratings::Elo;

=pod

=head1 NAME

Sudoku - Sudoku rating support library

=head1 SYNOPSIS

  use Sudoku;
  my @players = (undef, 
    { 'rating' => 1800, 'newr' => [1700, 1750], 'scores' => [100, 90, 80] },
    { 'rating' => 1200, 'newr' => [1200, 1250], 'scores' => [ 60, 70, 50] },
    { 'rating' => 1000, 'newr' => [1000, 1050], 'scores' => [ 60, 60, 60] },
    );
  Sudoku::CalculateRatings(@players);
  print "Player #1's new rating: $players[1]{'newr'}\n";

  
=head1 ABSTRACT

This Perl library provides support for Sudoku-related calculations.

=head1 DESCRIPTION

=over 4

=cut

sub CalculateDifficulty ($$\@);
sub CalculateRatings($\@);
sub CalculateRoundRatings($$$$\@);

=item ($difficulty, $mean_score) = Sudoku::CalculateDifficulty($elo, $r0, \@players);

Calculate the difficulty of this round's puzzle, as though it were
the unrated opponent of the players in a Scrabble tournament.

=cut

sub CalculateDifficulty ($$\@) {
  my $elo = shift;
  my $r0 = shift;
  my $psp = shift;
  my (@player_copies);
  my $notional_opponent = {
    'id' => @$psp + 1,
    'oldr' => 0,
    'ewins' => 0,
    'rgames' => 0,
    'scores' => [],
    };
  my $found_rated;
  my $max_score = 0;
  my $mean_score = 0;
  my $n_scores = 0;
  for my $i (1..$#$psp) {
    my $p = $psp->[$i];
    my $score = $p->{'scores'}[$r0] || next;
    $max_score = $score if $max_score < $score;
    $mean_score += $score;
    $found_rated++ if $p->{'rating'};
    $n_scores++;
    }
  $mean_score /= $n_scores if $n_scores;
  return (2000, $mean_score) unless $found_rated;
  for my $i (1..$#$psp) {
    my $p = $psp->[$i];
    my $score = $p->{'scores'}[$r0] || next;
    my $ewins = $max_score ? $score/$max_score : 0.5;
#   warn "$i $ewins";
    push(@player_copies, { 
      'id' => $i-1,
      'oldr' => $r0 > 0 ? $p->{'etc'}{'newr'}[$r0-1] : $p->{'rating'},
      'ewins' => $ewins,
      'scores' => [(0)x$i, $score],
      'rgames' => 1,
      'pairings' => [(-1)x$i,@$psp-1],
      });
    $notional_opponent->{'ewins'} += 1 - $ewins;
    $notional_opponent->{'rgames'} ++;
    $notional_opponent->{'pairings'}[$i-1] = $i-1;
    $notional_opponent->{'scores'}[$i-1] = $max_score-$score;
    }
  push(@player_copies, $notional_opponent);
  $elo->RateNewcomers(\@player_copies, -1, $r0, { map { $_ => $_ } qw(id newr oldr ewins rgames pairings scores) });
  return ($player_copies[-1]{'newr'}, $mean_score);
  }

=item ABSP::CalculateRatings($r0, @players)

Updates a list of hashes of player information to include tournament ratings.

=cut

sub CalculateRatings($\@) {
  my $maxr0 = shift;
  my $datap = shift;

  my $elo = new Ratings::Elo('rating_system' => 'sudoku');
  for my $r0 (0..$maxr0) {
    my $unrated;
    for my $id (1..$#$datap) {
      if ((!defined $datap->[$id]{'etc'}{'newr'}) || !defined $datap->[$id]{'etc'}{'newr'}[$r0]) {
	$unrated = 1;
	last;
	}
#     else { warn $datap->[$id]{'etc'}{'newr'}[$r0] }
      }
    next unless $unrated; # ratings are already cached for this round, skip
    my ($difficulty, $mean_score) = CalculateDifficulty($elo, $r0, @$datap);
    CalculateRoundRatings $elo, $difficulty, $mean_score, $r0, @$datap;
    }
  }

=item ABSP::CalculateRoundRatings($elo, $difficulty, $mean_score, $r0, @players)

Calculate ratings for one round.

=cut

sub CalculateRoundRatings($$$$\@) {
  my $elo = shift;
  my $difficulty = shift;
  my $mean_score = shift;
  my $r0 = shift;
  my $datap = shift;
  my @player_copies;
  my @notional_players;
  my $r1 = $r0+1;
# warn "Round $r1 difficulty=$difficulty mean_score=$mean_score";
  for my $i (1..$#$datap) {
    my $p = $datap->[$i];
    my $score = $p->{'scores'}[$r0] || 0;
    push(@player_copies, { 
      'name' => $p->{'name'},
      'id' => $i-1,
      'oldr' => $r0 > 0 ? $p->{'etc'}{'newr'}[$r0-1] : $p->{'rating'},
      'ewins' => $mean_score ? $score/$mean_score : 0.5,
      'lifeg' => $p->{'lifeg'} || 0,
      'scores' => [(0)x$i, $score],
      'rgames' => 1,
      'pairings' => [(-1)x$r0,$i+$#$datap-1],
      });
    push(@notional_players, {
      'name' => "fake $i",
      'id' => $i-1+$#$datap-1,
      'lifeg' => 0,
      'oldr' => $difficulty,
      'ewins' => $mean_score ? 1-$score/$mean_score : 0.5,
      'scores' => [(0)x$i, $mean_score-$score],
      'rgames' => 1,
      'pairings' => [(-1)x$r0,$i-1],
      });
    }
  push(@player_copies, @notional_players);
  my (%keymap) = 
    ( map { $_ => $_ } qw(id lifeg newr oldr ewins rgames pairings scores) );
  $elo->CopyField(\@player_copies, 'xrat_effr', 'oldr');
  $elo->RateNewcomers(\@player_copies, $r0, $r0, \%keymap);
  $elo->RateVeterans(\@player_copies, $r0, $r0, \%keymap);
# for my $p (@player_copies) { print "$r0 $p->{'newr'}\n"; }
  for my $i (1..$#$datap) {
    $datap->[$i]->NewRating($r0, int(0.5+$player_copies[$i-1]{'newr'}));
    }
  }

=back

=cut

1;
