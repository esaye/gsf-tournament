#!/usr/bin/perl

# Copyright (C) 2010 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::ReportCommand::ExtremeGames;

use strict;
use warnings;
use threads::shared;
use TSH::Log;
use TSH::Utility;
use Carp;
use TSH::ReportCommand;

our (@ISA) = qw(TSH::ReportCommand);

=pod

=head1 NAME

TSH::ReportCommand::ExtremeGames - common code for commands that report on extreme games

=head1 SYNOPSIS

This subclass supports features common to commands that report on
extreme games (high win, high loss, etc.).
  
=head1 ABSTRACT

$rc->FindEntries();

Games are represented as lists: [$score1, $score2, $p1, $p2, $r0, $rat1, $rat2].
List items beyond these may be defined on an application-specific basis.

=cut

=head1 DESCRIPTION

=over 4

=cut

sub FindEntries ($) {
  my $this = shift;
  $this->{'rcopt'}{'entries'} = TSH::Division::FindExtremeGames::Search(
    $this->{'rcopt'}{'dp'},
    $this->{'rcopt'}{'max_entries'},
    $this->{'rcopt'}{'selector'},
    $this->{'rcopt'}{'comparator'},
    );
  }

sub IsUnratedUpset ($) {
  my $gamep = shift;
  my $dp = $gamep->[2]->Division(); # get division from player one
  my $rating_system = $dp->RatingSystem();
  return (defined $gamep->[0]) # player one has a score
      && (defined $gamep->[1]) # player two has a score
      && $gamep->[0] > $gamep->[1] # player one won
      && (!$gamep->[5]) # player one is unrated
      && $rating_system->CompareRatings($gamep->[5],  $gamep->[6]) < 0 # player one is rated lower than player two
  }

sub IsUpset ($) {
  my $gamep = shift;
  my $dp = $gamep->[2]->Division(); # get division from player one
  my $rating_system = $dp->RatingSystem();
  return (defined $gamep->[0]) # player one has a score
      && (defined $gamep->[1]) # player two has a score
      && $gamep->[0] > $gamep->[1] # player one won
      && $gamep->[5] # player one is rated
      && $rating_system->CompareRatings($gamep->[5],  $gamep->[6]) < 0 # player one is rated lower than player two
  }

=back

=cut

=head1 BUGS

None reported.

=cut

