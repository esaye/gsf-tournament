#!/usr/bin/perl

# Copyright (C) 2008 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Division::Team;

use strict;
use warnings;

=pod

=head1 NAME

TSH::Division::Team - utilities for team tournaments

=head1 SYNOPSIS

  ($team1p, $team2p, ...) = TSH::Division::Team::GroupByTeam(\@players);
  print $team1p->{'members'}[0]->Name() . " belongs to team $team1p->{'name'}.\n";

=head1 ABSTRACT

This module contains utilities used at tournaments in which
players are divided into teams.

=cut

sub GroupByTeam ($);

=head1 DESCRIPTION

=over 4

=cut
 
=item $teamsp = GroupByTeam(\@players);

Given a reference to a list of players, returns a reference to a
hash mapping team name to list of references to the players belonging
to the team.

=cut

sub GroupByTeam ($) {
  my $psp = shift;
  my %teams;
  for my $p (@$psp) {
    my $team = $p->Team();
    $team = '' unless defined $team;
    push(@{$teams{$team}}, $p);
    }
  return \%teams;
  }


=item $groups = GroupForInitialPairings($groupsize, \@players);

Given a sorted list of players, divide them up into groups of C<$groupsize> players.
If the number of players is not evenly divisible by the group size, include one
oversize group less than twice the group size.
Do not place two members of the same team in the same group, except when the team
has more members than the number of groups.
When assigning players to groups, try to pick one player randomly from each
number-of-groups-ile.
Return a list of references to a list of members of each pairing group.

=cut

sub GroupForInitialPairing ($$) {
  my $groupsize = shift;
  my $psp = shift;
  my $teamsp = GroupByTeam $psp;
  my @groups;
  }

=head1 BUGS

None known.

=cut

1;
