#!/usr/bin/perl

# Copyright (C) 2008 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Player;

use strict;
use warnings;

use TSH::Utility;

=pod

=head1 NAME

TSH::Player::TuffLuck - extend TSH::Player to perform tuffluck computation

=head1 SYNOPSIS

  use TSH::Player;
  use TSH::PLayer::TuffLuck;
  my $p = new TSH::Player()
  my $tuffness = $p->TuffLuck($ngames);

=head1 ABSTRACT

TSH::Player::TuffLuck extends TSH::Player to compute tuffluck: the
sum of a player's n losing spreads of least magnitude.

=cut

=head1 DESCRIPTION

=over 4

=cut

=item ($tuffness, $spreadsp) = $p->TuffLuck($ngames);

Return the sum of a player's C<$ngames> losing spreads of least
magnitude and a reference to a list of those spreads.
The sum is set to zero if a player has not has C<$ngames> losses.

=cut

sub TuffLuck ($$) {
  my $this = shift;
  my $nscores = shift;

  my @losses;
  for my $r0 (0..$this->CountScores()-1) {
    my $ms = $this->Score($r0);
    next unless defined $ms;
    my $os = $this->OpponentScore($r0);
    next unless defined $os;
    next unless $ms < $os;
    push(@losses, $os-$ms);
    }
  return (0,[]) if @losses < $nscores;
  (@losses) = sort { $a <=> $b } @losses;
  my $tuffness = 0;
  my @truncated : shared = @losses[0..$nscores-1]; # splices are not thread-safe
  for my $loss (@truncated) { $tuffness += $loss; }
  return ($tuffness, \@truncated);
  }

=back

=cut

=head1 BUGS

None known.

=cut


1;


