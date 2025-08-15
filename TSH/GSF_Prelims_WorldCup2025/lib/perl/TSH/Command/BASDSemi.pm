#!/usr/bin/perl

# Copyright (C) 2007 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::BASDSemi;

use strict;
use warnings;

use TSH::Utility qw(Debug DebugOn DebugOff DebugDumpPairings);

DebugOn('BASD');

our (@ISA) = qw(TSH::PairingCommand);
our ($pairings_data);

=pod

=head1 NAME

TSH::Command::BASDSemi - implement the C<tsh> BASDSemi command

=head1 SYNOPSIS

  my $command = new TSH::Command::BASDSemi;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::BASDSemi is a subclass of TSH::PairingCommand.

=cut

=head1 DESCRIPTION

=over 4

=cut

sub initialise ($$$$);
sub new ($);
sub Run ($$@);
sub PairSemifinals ($$);

sub initialise ($$$$) {
  my $this = shift;
  my $path = shift;
  my $namesp = shift;
  my $argtypesp = shift;

  $this->{'help'} = <<'EOF';
Use this command to compute the semifinal rounds of the 
Big Apple Scrabble Showdown, where the top two players
from each initial flight play a three-game series (A1-B2,
B1-A2) while the rest play in round robin groups of four:
A3-B4-B7-A8, B3-A4-A7-B8, A5-A6-B5-B6, A9-A10-B9-B10.
EOF
  $this->{'names'} = [qw(basds basdsemi)];
  $this->{'argtypes'} = [qw(Division)];
# print "names=@$namesp argtypes=@$argtypesp\n";

  return $this;
  }

sub new ($) { return TSH::Utility::new(@_); }

=item $command->Run($tournament, @parsed_args)

Should run the command in the context of the given
tournament with the specified parsed arguments.

=cut

sub Run ($$@) { 
  my $this = shift;
  my $tournament = shift;
  my ($dp) = $this->{'dp'} = shift;
  my $setupp = $this->SetupForPairings(
    'division' => $dp,
    'source0' => 8,
    'target0' => 9,
    ) 
    or return 0;
  my $psp = $setupp->{'players'};
  $this->PairSemifinals($psp);
# $dp->Dirty(1); # handled by $dp->Pair();
  $this->Processor()->Flush();
  }

sub PairSemifinals ($$) {
  my $this = shift;
  my $psp = shift;
  @$psp = TSH::Player::SortByStanding(8, @$psp);
  # first entry in @A and @B is empty, for better late code legibility
  my (@A) = map { $_->ID() } @$psp[0,3,4,7,8,11,12,15,16,19];
  my (@B) = map { $_->ID() } @$psp[1,2,5,6,9,10,13,14,17,18];
  Debug('BASD', 'A: %s', join(',', @A));
  Debug('BASD', 'B: %s', join(',', @B));
  unshift(@A, undef);
  unshift(@B, undef);
  my $dp = $this->{'dp'};
  for my $r0 (9..11) {
    $dp->Pair($A[1], $B[2], $r0);
    $dp->Pair($A[2], $B[1], $r0);
    }
  for my $gpp (
    [$A[3], $B[4], $B[7], $A[8]],
    [$B[3], $A[4], $A[7], $B[8]],
    [$A[5], $A[6], $B[5], $B[6]],
    [$A[9], $A[10], $B[9], $B[10]],
    ) {
    $dp->Pair($gpp->[0], $gpp->[3], 9);
    $dp->Pair($gpp->[1], $gpp->[2], 9);
    $dp->Pair($gpp->[0], $gpp->[2], 10);
    $dp->Pair($gpp->[1], $gpp->[3], 10);
    $dp->Pair($gpp->[0], $gpp->[1], 11);
    $dp->Pair($gpp->[2], $gpp->[3], 11);
    }
  }


=back

=cut

1;
