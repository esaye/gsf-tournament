#!/usr/bin/perl

# Copyright (C) 2010 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Division::FindExtremePlayers;

use strict;
use warnings;

=pod

=head1 NAME

TSH::Division::FindExtremePlayers - common code for finding extreme players

=head1 SYNOPSIS

  TSH::Division::FindExtremePlayers::Search($dp, $count, \&filter, \&ranker, \&evaluator);

=head1 ABSTRACT

This module is used by the AVErages, TUFFluck and other
commands to generate a list of the top however many players, arbitrarily
selected and ranked.

Players are represented as lists: [$key_value, $p].

=cut

sub Search ($$$$;$$);

=head1 DESCRIPTION

=over 4

=cut
 
=item $listp = Search($dp, $count, \&filter, \&ranker, \&evaluator);

Return a reference to a list of up to $count players, each represented as
[$key_value, $p].  Only players which return true when
passed to &filter will be included, and if there are more than $count,
the list will be sorted using &ranker as a sortsub and only the first
$count members returned.  
&ranker must be prototyped (see perldoc -f sort).
If C<&evaluator> is not null, then C<$list = [&$evaluator($p), $p]> will
be used to create the player representations; otherwise the evaluator
sub defaults to sub { 0 }.

=cut

sub Search ($$$$;$$) {
  my $dp = shift;
  my $count = shift;
  my $filter = shift;
  my $ranker = shift;
  my $evaluator = shift || sub { 0 };
  my $postfilter = shift || sub { 1 };
  Carp::confess "no filter" unless (defined $filter) && ref($filter) eq 'CODE';
  Carp::confess "no ranker" unless (defined $ranker) && ref($ranker) eq 'CODE';
  my (@ps) = grep { &$postfilter($_) } 
    map { [ &$evaluator($_), $_ ] } grep { &$filter($_) } $dp->Players();
  my @entries;
  for my $p (@ps) {
    if (@entries < $count) {
      push(@entries, $p);
      }
    else {
      push(@entries, $p);
      if (@entries > 2 * $count) {
	@entries = sort $ranker @entries;
	splice(@entries, $count); # not shared, so splice is thread-safe
	}
      }
    }
  @entries = sort $ranker @entries;
  if (@entries > $count) {
#   warn "SPLICING\n"; for my $i (0..$#entries) { my $ep = $entries[$i]; print STDERR "$ep->[0] $ep->[1] $ep->[4] $ep->[2]{'name'} $ep->[3]{'name'}\n"; }
    splice(@entries, $count); # not shared, so splice is thread-safe
    }
  return \@entries;
  }


=head1 BUGS

None known.

=cut

1;
