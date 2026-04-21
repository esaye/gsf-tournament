#!/usr/bin/perl

# Copyright (C) 2012 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Division::Pairing::Random;

use strict;
use warnings;

use TSH::Utility qw(Debug);

our(@ISA) = 'Exporter';
our(@EXPORT_OK) = qw(PairRandom);

=pod

=head1 NAME

TSH::Division::Pairing::Random - random algorithm for pairings

=head1 SYNOPSIS

  TSH::Division::Pairing::Random::PairRandom(\@players, \%options);

=head1 ABSTRACT

This module implements random pairings on a group of players,
restricted as necessary according to repeat and start vs. reply
constraints.

=cut

sub PairRandom ($$);

=head1 DESCRIPTION

=over 4

=cut
 
=item $success = PairRandom(\@players, \%options)

Randomly pair C<@players>.
Options are as follows.

filter: as per TSH::PairingCommand::SetupForPairings

target0: as per TSH::PairingCommand::SetupForPairings

track_first: if true, firsts and seconds are balanced


=cut

sub PairRandom ($$) {
  my $psp = shift;
  return unless @$psp;
  my $optionsp = shift;
  my $track_firsts = $optionsp->{'track_firsts'};
  if (TSH::Player::PairGRT($psp,
    # opponent preference ranking
    # $psp is arg 0
    # $pindex is arg 1
    # $oppindex is arg 2
    sub {
      my $p = $_[0][$_[1]];
      my $pid = $p->ID();
      my $o = $_[0][$_[2]];
      my $oid = $o->ID();
      my $lastoid = ($p->OpponentID(-1)||-1);
      my $thisrep = $p->Repeats($oid); 
      my $sameopp = ($oid == $lastoid);
      my $distance = $p->Random() - $o->Random();
      my $pairsvr = $track_firsts ? 2-abs(($p->Firsts()-$p->Seconds() <=> 0)  -($o->Firsts()-$o->Seconds() <=> 0)) : 0;

      Debug 'GRT', 'pref %d-%d rep=%d prev=%d svr=%d dist=%d', $pid, $oid, $thisrep, $sameopp, $pairsvr, $distance;
      pack('NCCNN',
	$distance, # prefer random opponents
	$sameopp, # avoid previous opponent
	$pairsvr, # pair those due to start vs those due to reply
 	$thisrep, # minimize repeats
	$_[2], # to recover player ID)
        )
      },
    # allowed opponent filter
    $optionsp->{'filter'},
    # optional arguments to subs
    [],
    # target round
    $optionsp->{'target0'},
    )) {
    $psp->[0]->Division()->Dirty(1);
    return 1;
    }
  return 0;
  }

=back

=cut

1;
