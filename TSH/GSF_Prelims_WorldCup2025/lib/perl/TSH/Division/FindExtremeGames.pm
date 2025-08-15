#!/usr/bin/perl

# Copyright (C) 2005 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Division::FindExtremeGames;

use strict;
use warnings;

use threads::shared;

=pod

=head1 NAME

TSH::Division::FindExtremeGames - algorithms for finding high/low wins/losses

=head1 SYNOPSIS

  TSH::Division::FindExtremeGames::Search($dp, $count, \&filter, \&ranker);

=head1 ABSTRACT

This module is used by the HighLoss, HighWin, LowLoss and LowWin
commands to generate a list of the top however many games, arbitrarily
selected and ranked.

Games are represented as lists: [$score1, $score2, $p1, $p2, $r0, $rat1, $rat2].
List items beyond these may be defined on an application-specific basis.

=cut

sub Search ($$$$;$);

=head1 DESCRIPTION

=over 4

=cut
 
=item $listp = Search($dp, $count, \&filter, \&ranker[, \$filterArg]);

Return a reference to a list of up to $count games, each represented as
[$score1, $score2, $p1, $p2, $r0, $rat1, $rat2].  Only games which return true when
passed to &filter will be included, and if there are more than $count,
the list will be sorted using &ranker as a sortsub and only the first
$count members returned.  &ranker must be prototyped (see perldoc -f
sort). C<$filterArg> is passed as a second argument to C<&filter>.

=cut

sub Search ($$$$;$) {
  my $dp = shift;
  my $count = shift;
  my $filter = shift;
  my $ranker = shift;
  my $filterArg = shift;
  Carp::confess "no filter" unless (defined $filter) && ref($filter) eq 'CODE';
  Carp::confess "no ranker" unless (defined $ranker) && ref($ranker) eq 'CODE';

  my @entries : shared;
  for my $p ($dp->Players()) {
    for my $r0 (0..$p->CountScores()-1) {
      my $o = $p->Opponent($r0);
      my $gamep = &share([]);
      push(@$gamep,
        $p->Score($r0), $p->OpponentScore($r0), $p, $p->Opponent($r0), $r0, $p->Rating(), ($o ? $o->Rating() : 0)
        );
      next unless &$filter($gamep, $filterArg);
      if (@entries < $count) {
	push(@entries, $gamep);
        }
#     elsif (&$ranker($gamep, $entries[$count-1]) < 0) {
      else {
	push(@entries, $gamep);
	if (@entries > 2 * $count) {
	  @entries = sort $ranker @entries;
	  # splicing is not thread-safe
	  TSH::Utility::SpliceSafely(@entries, $count, scalar(@entries));
	  }
        }
      }
    }
  @entries = sort $ranker @entries;
  if (@entries > $count) {
#   warn "SPLICING\n"; for my $i (0..$#entries) { my $ep = $entries[$i]; print STDERR "$ep->[0] $ep->[1] $ep->[4] $ep->[2]{'name'} $ep->[3]{'name'}\n"; }
    TSH::Utility::SpliceSafely(@entries, $count, scalar(@entries));
    }
  return \@entries;
  }


=head1 BUGS

None known.

=cut

1;
