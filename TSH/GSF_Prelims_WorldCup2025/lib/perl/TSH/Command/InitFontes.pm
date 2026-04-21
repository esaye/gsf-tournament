#!/usr/bin/perl

# Copyright (C) 2005-2018 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::Command::InitFontes;

use strict;
use warnings;

use TSH::PairingCommand;
use TSH::Player;
use TSH::Utility qw(Debug DebugOn);
use TSH::Division::Pairing::Berger;

our (@ISA) = qw(TSH::PairingCommand);

=pod

=head1 NAME

TSH::Command::InitFontes - implement the C<tsh> InitFontes command

=head1 SYNOPSIS

  my $command = new TSH::Command::InitFontes;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::InitFontes is a subclass of TSH::Command.

=cut

=head1 DESCRIPTION

=over 4

=cut

sub ChooseGroupsRandomly ($$);
sub ChooseGroupsSnaked ($$$);
sub initialise ($$$$);
sub new ($);
sub PairPartiallyPaired ($$$);
sub Run ($$@);

=item $parserp->ChooseGroupsRandomly()

Calculate $this->{'if_groups'} based on $this->{'if_players'}.
Assign players to pairing groups randomly from each nth-ile.

=cut

sub ChooseGroupsRandomly ($$) {
  my $this = shift;
  my $nrounds = shift;
  $nrounds++ unless $nrounds % 2;

# my $psp = $this->{'if_players'}; # splices are not thread-safe
  my @psp = @{$this->{'if_players'}};
  my $np = scalar(@psp);
  my @groups;
  # is everyone in one group?
  if ($np <= 2*$nrounds) { 
    Debug 'IF', 'Everyone is in one group';
    $this->{'if_groups'} = [\@psp]; return; 
    }
  # do players not divide evenly?
  if (my $residue = $np % ($nrounds + 1)) { 
    my @oddballs;
    if ($nrounds == 3) { 
      # hard-coded, hand-optimised, the old-fashioned way
      if ($residue == 1) {
	# pick five players, one from each sextile except the top
	for (my $section=5; $section>=1; $section--) {
	  unshift(@oddballs,splice(@psp,int($np*($section+rand(1))/6),1));
	  }
	}
      elsif ($residue == 2) {
	# pick six players, one from each sextile
	for (my $section=5; $section>=0; $section--) {
	  unshift(@oddballs, splice(@psp, int($np*($section+rand(1))/6),1));
	  }
	}
      elsif ($residue == 3) {
	# pick three players, one from each quarter except the top
	for (my $section=3; $section>=1; $section--) {
	  unshift(@oddballs, splice(@psp, int($np*($section+rand(1))/4),1));
	  }
	}
      }
    else { # in this case $nrounds != 3
      my $parts = $nrounds + 1;
      my $top = $residue % 2;
      if ($residue != $nrounds) {
	$parts += $residue + $top;
        }
      # pick $parts-$top players, one from each $parts-ile except possibly the top
      for (my $section=$parts-1; $section>=$top; $section--) {
	unshift(@oddballs, splice(@psp, int($np*($section+rand(1))/$parts),1));
	}
      }
    Debug 'IF', 'Odd players: %s', join(',', map($_->{'id'}, @oddballs));
    push(@groups, \@oddballs);
    }
  # repeatedly pick one random player from each ($nrounds+1)-ile
  for (my $n4 = int(@psp/($nrounds+1)); $n4 > 0; $n4--) {
    my @rr = ();
    for (my $quartile = $nrounds; $quartile >= 0; $quartile--) 
      { unshift(@rr, splice(@psp, $quartile*$n4 + rand($n4), 1)); }
    Debug 'IF', 'Group: %s', join(',', map($_->{'id'}, @rr));
    push(@groups, \@rr);
    }
  $this->{'if_groups'} = \@groups;
  return;
  }

=item $parserp->ChooseGroupsSnaked($nrounds, $snake_style)

Calculate $this->{'if_groups'} based on $this->{'if_players'}.
Assign players to groups boustrophedonically.
If C<$snake_style =~ /\bstrict\b/i>, do the boustrophedon even if it
leaves many groups with byes.
If C<$snake_style =~ /\bclassify\b/i>, assign players to classes 'A', 'B', ....

=cut

sub ChooseGroupsSnaked ($$$) {
  my $this = shift;
  my $nrounds = shift;
  my $snake_style = shift;
  $nrounds++ unless $nrounds % 2;
# warn $snake_style;

  my $classify = $snake_style =~ /\bclassify\b/i;

# my $psp = $this->{'if_players'}; # splices are not thread-safe
  my @psp = @{$this->{'if_players'}};
  my $np = scalar(@psp);
  # is everyone in one group?
  if ($np <= 2*$nrounds) { $this->{'if_groups'} = [\@psp]; return; }
  # do players not divide evenly?
  my @oddballs;
  if ($np % ($nrounds + 1) != $nrounds && $snake_style !~ /\bstrict\b/i) { # when missing just one player, it's best to leave the grid as is
    while (my $residue = $np % ($nrounds + 1)) { 
      push(@oddballs, splice(@psp, int((@psp+1)/2), 1));
      $np--;
      }
    }
  Debug 'IF', '(S) Odd players: %s', join(',', map($_->{'id'}, @oddballs));
  my $groupsize = $nrounds + 1;
  my $ngroups = int(($groupsize-1+@psp)/$groupsize);
  my @groups;
  my @rows;
  for my $i (1..$groupsize) {
    my (@row) = splice(@psp, 0, $ngroups);
    @row = reverse @row unless $i % 2;
    push(@rows, \@row);
#   Debug 'IF', '(S) Row: %s', join(',', map($_->{'id'}, @row));
    }
  my $class = 'A';
  for my $i (1..$ngroups) {
    my (@group) = map { pop @$_ || () } @rows;
    push(@groups, \@group);
    if ($classify) {
      for my $p (@group) { $p->Class($class) }
      $class++;
      }
    Debug 'IF', '(S) Group: %s', join(',', map($_->{'id'}, @group));
    }
  if (@oddballs) {
    my $lastgroup = $groups[-1];
    splice(@$lastgroup, @$lastgroup/2, 0, @oddballs);
    Debug 'IF', '(S) Odd Group: %s', join(',', map($_->{'id'}, @$lastgroup));
    }
  $this->{'if_groups'} = \@groups;
  return;
  }

=item $parserp->initialise()

Used internally to (re)initialise the object.

=cut

sub initialise ($$$$) {
  my $this = shift;
  my $path = shift;
  my $namesp = shift;
  my $argtypesp = shift;

  DebugOn 'IF';
  $this->{'help'} = <<'EOF';
Use the InitFontes command to manually a fixed number of rounds
before starting a Swiss-paired tournament.
The field is divided into equal parts by pretournament ranking,
and round robin groups are formed by drawing one group member
from each part of the field.
EOF
  $this->{'names'} = [qw(if initfontes)];
  $this->{'argtypes'} = [qw(NumberOfRounds Division)];
  $this->{'if_groups'} = [];
  $this->{'if_players'} = [];
# print "names=@$namesp argtypes=@$argtypesp\n";

  return $this;
  }

sub new ($) { return TSH::Utility::new(@_); }

=item $success = $command->PairPartiallyPaired($nrounds, $division);

Try to pair those players who have some pairings in the first $nrounds
rounds amongst themselves, so that the rest can be paired in quads.

=cut

sub PairPartiallyPaired ($$$) {
  my $this = shift;
  my $nrounds = shift;
  my $dp = shift;
  my $tournament = $dp->Tournament();
  # TODO: should check for active players
  my (@ps) = grep { 
    (defined $_->OpponentID(0))
    || (defined $_->OpponentID(1))
    || (defined $_->OpponentID(2)) 
    } $dp->Players();

  Debug 'IF', 'Partly paired: %s', join(',', map($_->{'id'}, @ps));
  for my $r0 (0..2) {
    my (@rps) = grep { !defined $_->OpponentID($r0) } @ps;
    Debug 'IF', 'Need to pair in Rd. %d: %s', $r0+1, join(',', map($_->{'id'}, @rps));
    if (@rps % 2) { $tournament->TellUser('eifpppo', 1); return 0; }
    while (@rps > 4) {
      my $p = shift @rps;
      my $offset = int((3-$r0)*@rps/4);
      my $found = 0;
      for my $i (1..@rps) {
	my $j = ($i + $offset) % @rps;
	my $opp = $rps[$j];
	next if $p->CountRepeats($opp) > 0;
	splice(@rps, $j, 1);
	$dp->Pair($p->ID(), $opp->ID(), $r0, 0);
	$found = 1;
	Debug 'IF', '%d vs %d on try %d, %d left', $p->ID(), $opp->ID(), $i, scalar(@rps);
	last;
	}
      unless ($found) {
	$tournament->TellUser('eifstuck', "can't pair #$p->{'id'} $p->{'name'}");
	return 0;
	}
      }
    Debug 'IF', 'Still left: %s', join(',', map($_->{'id'}, @rps));
    if (@rps == 2) {
      my $p = shift @rps;
      my $opp = shift @rps;
      if ($p->CountRepeats($opp) > 0) {
	$tournament->TellUser('eifstuck', "$p->{'id'} and $opp->{'id'} have already played");
	return 0;
        }
      $dp->Pair($p->ID(), $opp->ID(), $r0, 0);
      Debug 'IF', '%d vs %d ok', $p->ID(), $opp->ID();
      }
    # try 1-3 2-4
    if ($rps[0]->CountRepeats($rps[2]) == 0
     && $rps[1]->CountRepeats($rps[3]) == 0) {
      $dp->Pair($rps[0]->ID(), $rps[2]->ID(), $r0, 0);
      $dp->Pair($rps[1]->ID(), $rps[3]->ID(), $r0, 0);
      }
    # try 1-4 2-3
    elsif ($rps[0]->CountRepeats($rps[3]) == 0
     && $rps[1]->CountRepeats($rps[2]) == 0) {
      $dp->Pair($rps[0]->ID(), $rps[3]->ID(), $r0, 0);
      $dp->Pair($rps[1]->ID(), $rps[2]->ID(), $r0, 0);
      }
    # try 1-2 3-4
    elsif ($rps[0]->CountRepeats($rps[1]) == 0
     && $rps[2]->CountRepeats($rps[3]) == 0) {
      $dp->Pair($rps[0]->ID(), $rps[1]->ID(), $r0, 0);
      $dp->Pair($rps[2]->ID(), $rps[3]->ID(), $r0, 0);
      }
    else {
      $tournament->TellUser('eifstuck', "Can't pair last four");
      return 0;
      }
    }
  $dp->Dirty(1);
  $this->Processor()->Flush();
  return 1;
  }

=item $command->Run($tournament, @parsed_args)

Should run the command in the context of the given
tournament with the specified parsed arguments.

=cut

sub Run ($$@) { 
  my $this = shift;
  my $tournament = shift;
  my $config = $tournament->Config();
  my $allow_gaps = $config->Value('allow_gaps');
  my ($nrounds, $dp) = @_;
  my $dname = $dp->Name();
  Debug 'IF', "InitFontes: nrounds=$nrounds, dname=$dname";
  # if pairings already exist
  if ($dp->LastPairedRound0() != -1) {
    if ($allow_gaps) {
      if ($nrounds != 3) {
	$tournament->TellUser('eifnotodd', $nrounds);
	return 0;
        }
      # try to complete partial initial pairings
      if (!$this->PairPartiallyPaired($nrounds, $dp)) { return 0; }
      }
    else {
      $tournament->TellUser('ehaspair', $dname);
      return 0; 
      }
    }
  # else pairing from first round
  my $sortedp = $dp->GetUnpairedRound(0);
  TSH::Player::SpliceInactive @$sortedp, $nrounds, 0;
  my $rr_schedule_size = $dp->CountActivePlayers() - 1;
  $rr_schedule_size ++ unless $rr_schedule_size % 2;
  my $rr_available = int($nrounds/$rr_schedule_size);
  if ($rr_available) {
    Debug 'IF', "1 RR = $rr_schedule_size rounds; $rr_available RRs available in $nrounds rounds.";
    $this->Processor()->Process("roundrobin $rr_available $dname");
    $nrounds -= $rr_available * $rr_schedule_size;
    # fall through
    }
  if ($nrounds == 2) {
    $this->Processor()->Process("pq 4 $rr_available 0 $dname; pq 3 $rr_available 0 $dname");
    return 0;
    }
  unless (1 || $nrounds % 2) { # even-length code seems to be working as of 2013-12-28
    $tournament->TellUser('eifnotodd', $nrounds);
    return 0;
    }
  $tournament->TellUser('iifok', $dname);

  # calculate pairings
  @$sortedp = TSH::Player::SortByInitialStanding @$sortedp;
  $this->{'if_players'} = $sortedp;
  if (my $snake_style = $config->Value('initial_snaked')) {
    $this->ChooseGroupsSnaked($nrounds, $snake_style);
    }
  else {
    $this->ChooseGroupsRandomly($nrounds);
    }
# Debug 'IF', "nrounds=$nrounds";
  TSH::Division::Pairing::Berger::PairGroups($this->{'if_groups'}, $nrounds);
  $dp->Dirty(1);
  $this->Processor()->Flush();
  $tournament->TellUser('idone');
  return;
  }

=back

=cut

=head1 BUGS

Makes some inappropriate use of TSH::Player internals.

Should check to see if the general Berger code works for $nrounds == 3,
and if so delete the code specific to that case.

Should check to see if the general Berger code works well in general, too.

=cut

1;
