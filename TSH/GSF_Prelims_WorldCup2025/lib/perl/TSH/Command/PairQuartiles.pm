#!/usr/bin/perl

# Copyright (C) 2005-2018 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::Command::PairQuartiles;

use strict;
use warnings;

use TSH::PairingCommand;
use TSH::Player;
use TSH::Utility qw(Debug);

our (@ISA) = qw(TSH::PairingCommand);

=pod

=head1 NAME

TSH::Command::PairQuartiles - implement the C<tsh> PairQuartiles command

=head1 SYNOPSIS

  my $command = new TSH::Command::PairQuartiles;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::PairQuartiles is a subclass of TSH::Command.

=cut

=head1 DESCRIPTION

=over 4

=cut

sub initialise ($$$$);
sub new ($);
sub Run ($$@);

=item $parserp->initialise()

Used internally to (re)initialise the object.

=cut

sub initialise ($$$$) {
  my $this = shift;
  my $path = shift;
  my $namesp = shift;
  my $argtypesp = shift;

  $this->{'help'} = <<'EOF';
Use the PairQuartiles command to manually add a round of pairings
in which players face opponents randomly selected from a designated
quartile, avoiding consecutive repairings and initial exagony,
matching starters vs. repliers, and minimizing repeats.
EOF
  $this->{'names'} = [qw(pairquartiles pq)];
  $this->{'argtypes'} = [qw(Quartile Repeats BasedOnRound Division)];
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
  my ($quartile1, $repeats, $sr, $dp) = @_;
  my $config = $tournament->Config();
  my $track_firsts = $config->Value('track_firsts');
  my $sr0 = $sr-1;

  my $setupp = $this->SetupForPairings(
    'division' => $dp, 'source0' => $sr0, 'repeats' => $repeats,
    'pairing_system_name' => "quartile 1-$quartile1",
    ) or return 0;
# $dp->ComputeRanks($sr0, {'splice_paired'=>1});
  $dp->ComputeRanks($sr0);
# $setupp->{'exagony'} ||= $config->Exagony($setupp->{'target0'});
  
  my (@quartile_pairings) = @{(
    [],
    [],
    [1,0,3,2,2],
    [2,3,0,1,1],
    [3,2,1,0,0]
    )[$quartile1]};
  unless (@quartile_pairings) {
    print "Invalid quartile.\n";
    return;
    }
  my $psp = $setupp->{'players'};
  if (@{$psp} == 2) {
    $dp->Pair($psp->[0]->ID(), $psp->[1]->ID(), $setupp->{'target0'}, 1);
    $this->TidyAfterPairing($dp);
    return;
    }
  my $quartile_size = @$psp / 4;
  Debug('PQ', join(',', map { $_->{'id'} } @$psp));
# warn scalar(@$psp) . ' ' . $quartile_size;
# die &{$setupp->{'filter'}}($psp, 29, 102);
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
#     warn $o->RoundRank($sr0) . ' ' . $p->RoundRank($sr0) . ' ' . int(($o->RoundRank($sr0)-1)/$quartile_size). ' '.int(($p->RoundRank($sr0)-1)/$quartile_size);
      # inactive or manually players get ranked and throw the following off, resulting in index to @quartile_pariings not having a valid value
      my $quartile =
        abs($quartile_pairings[int(($o->RoundRank($sr0)-1)/$quartile_size)] - int(($p->RoundRank($sr0)-1)/$quartile_size));
#       $quartile_pairings[int(($o->RoundRank($sr0)-1)/$quartile_size)] == int(($p->RoundRank($sr0)-1)/$quartile_size)
#	? 0 : 1 + abs($quartile_size*2-abs($_[1]-$_[2]));

#     warn join(' ', 'sr0', $sr0, 'oid', $oid, 'ork', $o->RoundRank($sr0), 'pid',  $pid, 'prk', $p->RoundRank($sr0), int(($o->RoundRank($sr0)-1)/$quartile_size), int(($p->RoundRank($sr0)-1)/$quartile_size), $quartile, $quartile_size);
      my $pairsvr = $track_firsts ? 2-abs(($p->{'p1'}-$p->{'p2'} <=> 0)  -($o->{'p1'}-$o->{'p2'} <=> 0)) : 0;
      Debug 'GRT', 'pref %d-%d rep=%d prev=%d svr=%d q=%d', $pid, $oid, $thisrep, $sameopp, $pairsvr, $quartile;
      pack('NCCNNN',
	$quartile, # prefer opponents in correct quartile
	$sameopp, # avoid previous opponent
	$pairsvr, # pair those due to start vs those due to reply
 	$thisrep, # minimize repeats
	$distance, # prefer random opponents
	$_[2], # to recover player ID
	)
      },
    # allowed opponent filter
    $setupp->{'filter'},
    # optional arguments to subs
    [],
    # target round
    $setupp->{'target0'},
    )) {
    $this->TidyAfterPairing($dp);
    }
  else {
    $tournament->TellUser('epfail');
    }
  }

=back

=cut

=head1 BUGS

Makes inappropriate use of private functions in TSH::Player.

=cut

1;

