#!/usr/bin/perl

# Copyright (C) 2010 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::ReportCommand::ExtremePlayers;

use strict;
use warnings;
use threads::shared;
use TSH::Division::FindExtremePlayers;
use TSH::Log;
use TSH::ReportCommand;

our (@ISA) = qw(TSH::ReportCommand);

=pod

=head1 NAME

TSH::ReportCommand::ExtremePlayers - common code for commands that report on extreme players

=head1 SYNOPSIS

This subclass supports features common to commands that report on
extreme players (AVErages, TUFFluck, etc.).
  
=head1 ABSTRACT

$entriesp = $cmd->FindEntries();

=cut

=head1 DESCRIPTION

=over 4

=cut

sub CompareBiggerValues ($$) {
  return $_[1][0] <=> $_[0][0];
  }

sub CompareSmallerValues ($$) {
  return $_[0][0] <=> $_[1][0];
  }

sub EvaluatePlayerAverageOpponentScore ($) {
  my $p = shift;
  my $sum;
  my $count;
  for my $r0 (0..$p->CountScores()-1) {
    next unless $p->Opponent($r0);
    $sum += $p->OpponentScore($r0);
    $count++;
    }
  return $count ? $sum/$count : 0;
  }

sub EvaluatePlayerAverageScore ($) {
  my $p = shift;
  my $sum;
  my $count;
  for my $r0 (0..$p->CountScores()-1) {
    next unless $p->Opponent($r0);
    $sum += $p->Score($r0);
    $count++;
    }
  return $count ? $sum/$count : 0;
  }

sub EvaluatePlayerRatingChange ($) {
  my $p = shift;
  return $p->NewRating(-1) - $p->Rating();
  }

sub FindEntries ($) {
  my $this = shift;
  $this->{'rcopt'}{'entries'} = TSH::Division::FindExtremePlayers::Search(
    $this->{'rcopt'}{'dp'},
    $this->{'rcopt'}{'max_entries'},
    $this->{'rcopt'}{'selector'},
    $this->{'rcopt'}{'comparator'},
    $this->{'rcopt'}{'evaluator'},
    $this->{'rcopt'}{'postfilter'},
    );
  }

sub IsActivePlayer ($) {
  return $_[0]->Active();
  }

sub IsActiveRatedPlayer ($) {
  return $_[0]->Active() && $_[0]->Rating();
  }

sub IsActiveUnratedPlayer ($) {
  return $_[0]->Active() && !$_[0]->Rating();
  }

=back

=cut

=head1 BUGS

None reported.

=cut

