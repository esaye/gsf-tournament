#!/usr/bin/perl

# Copyright (C) 2010 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Player;

use strict;
use warnings;

use TSH::Utility;

=pod

=head1 NAME

TSH::Player::LuckyStiff - extend TSH::Player to perform luckystiff computation

=head1 SYNOPSIS

  use TSH::Player;
  use TSH::PLayer::LuckyStiff;
  my $p = new TSH::Player()
  my $stiffness = $p->LuckyStiff($ngames);

=head1 ABSTRACT

TSH::Player::LuckyStiff extends TSH::Player to compute luckystiff: the
sum of a player's n winning spreads of least magnitude.

=cut

=head1 DESCRIPTION

=over 4

=cut

=item ($stiffness, $spreadsp) = $p->LuckyStiff($ngames);

Return the sum of a player's C<$ngames> losing spreads of least
magnitude and a reference to a list of those spreads.
The sum is set to zero if a player has not has C<$ngames> losses.

=cut

sub LuckyStiff ($$) {
  my $this = shift;
  my $nscores = shift;

  my @wins;
  for my $r0 (0..$this->CountScores()-1) {
    my $ms = $this->Score($r0);
    next unless defined $ms;
    my $os = $this->OpponentScore($r0);
    next unless defined $os;
    next unless $ms > $os;
    push(@wins, $ms-$os);
    }
  return (0,[]) if @wins < $nscores;
  (@wins) = sort { $a <=> $b } @wins;
  my $stiffness = 0;
  my @truncated : shared = @wins[0..$nscores-1]; # splices are not thread-safe
  for my $win (@truncated) { $stiffness += $win; }
  return ($stiffness, \@truncated);
  }

=back

=cut

=head1 BUGS

None known.

=cut


1;



