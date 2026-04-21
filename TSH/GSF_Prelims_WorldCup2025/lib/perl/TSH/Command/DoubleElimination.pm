#!/usr/bin/perl

# Copyright (C) 2012 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::DoubleElimination;

use strict;
use warnings;

use TSH::Utility qw(Debug DebugOn DebugOff DebugDumpPairings);
use TSH::Division::Pairing::Random qw(PairRandom);
use TSH::Command::KOTH;

DebugOn('DE');

our (@ISA) = qw(TSH::PairingCommand);
our ($pairings_data);

=pod

=head1 NAME

TSH::Command::DoubleElimination - implement the C<tsh> DoubleElimination command

=head1 SYNOPSIS

  my $command = new TSH::Command::DoubleElimination;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::DoubleElimination is a subclass of TSH::PairingCommand.

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
This command implements double elimination pairings for Prague.
Players in contention are paired randomly within win group; others
are paired KOTH with minimal repeats.  If contenders are odd, 
a designated alternate is assigned.
EOF
  $this->{'names'} = [qw(de doubleelimination)];
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
  my ($dp) = shift;
  my $config = $this->{'de_config'} = $tournament->Config();
  $this->{'de_alternate'} = $config->Value('de_alternate');
  if (!defined $this->{'de_alternate'}) {
    $tournament->TellUser('edeneedalt');
    return 0;
    };
  $this->{'de_alternate'} = $this->{'de_alternate'}->{$dp->Name()};
  if (!defined $this->{'de_alternate'}) {
    $tournament->TellUser('edeneedalt');
    return 0;
    };
  $this->{'de_alternate'} = $dp->Player($this->{'de_alternate'});
  my $bye_spread = $config->Value('bye_spread');
  if (!defined $bye_spread) {
    $tournament->TellUser('eneed_bye_spread');
    return 0;
    }
  $this->{'de_alternate'}->Deactivate($bye_spread);
  my $max_round0 = $dp->MaxRound0();
  if (!defined $max_round0) {
    $tournament->TellUser('eneed_max_rounds');
    return 0;
    }
  my $target0 = $dp->FirstUnpairedRound0();
  my $source0 = $target0 - 1;
  my $setupp = $this->SetupForPairings(
    'division' => $dp,
    'source0' => $source0,
    'gibson' => 0,
    'repeats' => $config->Value('max_rounds'),
    'nobye' => 1,
    ) 
    or return 0;

  my $psp = $setupp->{'players'};
  my (@wgs) = TSH::Division::MakeWinGroups($setupp->{'source0'}, $psp);

  my $aborted = 0;
  my $alternate_used = 0;
  for my $wgi (0..$#wgs) {
    my $wgp = $wgs[$wgi];
    Debug 'DE', "Examining win group $wgi: ".join('; ', map { $_->TaggedName() } @$wgp);
    if (!@$wgp) {
      Debug 'DE', '.. skipping empty group';
      next;
      }
    if (@$wgp % 2) { # if win group is odd
      if ($wgi == $#wgs || $wgs[$wgi+1][0]->Losses() >= 2) { 
	# if this is last contending win group, activate alternate
	if (!$alternate_used++) {
	  push(@$wgp, $this->{'de_alternate'});
	  $this->{'de_alternate'}->Activate();
	  $alternate_used++;
	  Debug 'DE', '.. group is odd, promoted alternate';
	  }
	elsif ($wgp->[0]->Losses() >= 2) {
	  Debug 'DE', '.. group is odd, alternate was already used';
	  }
	else {
	  die "assertion failed: group is odd, who used the alternate?";
	  }
        }
      else { # else promote high player from next group
	warn "TODO: should check repeats here";
	push(@$wgp, shift @{$wgs[$wgi+1]});
	Debug 'DE', '.. group is odd, promoted a player';
        }
      }
    if ($wgp->[0]->Losses() < 2) { # group is in contention
      Debug 'DE', 'pairing contenders';
      unless (PairRandom($wgp, {
	'filter' => $setupp->{'filter'},
	'target0' => $setupp->{'target0'},
	'track_firsts' => $config->Value('track_firsts'),
	})) {
	$tournament->TellUser('epfail');
	$aborted = 1;
	last;
	}
      }
    else { # group is not in contention
      Debug 'DE', 'pairing noncontenders';
      $setupp->{'players'} = [map {@$_} @wgs[$wgi..$#wgs]];
#     DebugOn 'GRT';
      if (@{$setupp->{'players'}} % 2) {
	$dp->ChooseBye($setupp->{'source0'}, $setupp->{'target0'}, $setupp->{'players'});
        }
      unless (TSH::Command::KOTH::PairComplete($setupp, undef)) {
	$tournament->TellUser('epfail');
	$aborted = 1;
        }
#     DebugOff 'GRT';
      last;
      }
    }
  $this->Processor()->Flush();
  $tournament->TellUser('idone') unless $aborted;
  return 0;
  }

=back

=cut

1;
