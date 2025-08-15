#!/usr/bin/perl

# Copyright (C) 2009 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::GroupRoundRobin;

use strict;
use warnings;

use TSH::PairingCommand;
use TSH::Utility;
use TSH::Division::Team;
use TSH::Division::Pairing::Berger;

our (@ISA) = qw(TSH::PairingCommand);
our @Pairings;
our @Starts;

=pod

=head1 NAME

TSH::Command::GroupRoundRobin - implement the C<tsh> GroupRoundRobin command

=head1 SYNOPSIS

  my $command = new TSH::Command::GroupRoundRobin;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::GroupRoundRobin is a subclass of TSH::PairingCommand.

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
Use the GroupRoundRobin command to pair players in round robin groups.
When you use this command, the last paired round must be fully, not partially paired.
This command takes the following arguments, all of which are required.
Division: the division in which the pairings will take place.
NumberOfRounds: the number of rounds the round robins should last.
Repetitions: the number of consecutive times each pairing should be repeated.
EOF
  $this->{'names'} = [qw(grr grouproundrobin)];
  $this->{'argtypes'} = [qw(Division NumberOfRounds Repeats)];
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
  my $dp = shift @_;
  my $nrounds = shift @_;
  my $repeats = shift @_;
  my $config = $tournament->Config();

  my $datap = $dp->{'data'};
  unless ($nrounds % 2) {
    $tournament->TellUser('egrreven', $nrounds);
    return;
    }

  # check that division is not partially paired
  my $round0 = $dp->FirstUnpairedRound0();
  if ($round0 != $dp->LastPairedRound0()+1) {
    $tournament->TellUser('errpartp');
    return;
    }
   
  my $psp = $dp->GetUnpairedRound($round0);
  my (@ps) = TSH::Player::SortByCurrentStanding @$psp;
  my $nplayers = scalar(@ps);
  my $ngroups = int(($nplayers+$nrounds)/(1+$nrounds));
  unless ($ngroups >= $nplayers % $nrounds) {
    $tournament->TellUser('egrrbad', $nplayers, $ngroups, $nrounds, $nrounds+1);
    return;
    }
  my (@groups);
  {
    my $dir = 1;
    my $g = 0;
    for my $i (0..$#ps) {
      push(@{$groups[$g]}, $ps[$i]);
      $g += $dir;
      if ($g >= $ngroups) {
	$g--;
	$dir = -1;
	}
      elsif ($g < 0) {
	$g++;
	$dir = 1;
	}
      }
  }

  print "groups:\n"; for my $g (@groups) { print join(",", map { $_->ID() } @$g), "\n"; }

  
  for my $g (@groups) {
    # partially copied from RoundRobin.pm
    # $p2sv1: 2 if p2 should start vs p1, -2 if p1 should start, 1 if don't care
    my $p2sv1 = 0;
    for (my $r0 = 0; ; $r0++) {
      my $p1oid = $g->[0]->OpponentID($r0);
      last unless defined $p1oid;
      next unless $p1oid == $g->[1]->ID();
      if (1 == (my $this_first = $g->[0]->First($r0))) { $p2sv1++; }
      elsif ($this_first == 2) { $p2sv1--; }
      }
    $p2sv1 = (2 * ($p2sv1 <=> 0) || 1);
    my $ngplayers = scalar(@$g);
    $ngplayers += $ngplayers % 2;
    my (@oppi) = @{
      $config->Value('round_robin_order') 
      || [reverse(2..$ngplayers)]
      };
    if ($config->Value('random_rr_order')) {
      # Knuth shuffle
      my $n = scalar(@oppi);
      while (--$n > 0) {
	my $k = int(rand()*($n+1));
	@oppi[$n,$k] = @oppi[$k,$n];
	}
      }
    for my $oppi (@oppi) {
      for my $j (1..$repeats) {
	TSH::Division::Pairing::Berger::PairGroup(
	  $g,
	  $oppi,
	  {
	    'assign_firsts' => $p2sv1 * ($j % 2 ? 1 : -1),
	    'koth' => 1,
	  }
	);
	}
      }
    }

  $tournament->TellUser('idone');

  $dp->Dirty(1);
  $this->Processor()->Flush();
  }

=back

=cut

=head1 BUGS

None known.

=cut

1;

