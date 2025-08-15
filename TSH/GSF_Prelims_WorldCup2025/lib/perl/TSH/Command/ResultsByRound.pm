#!/usr/bin/perl

# Copyright (C) 2007 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::ResultsByRound;

use strict;
use warnings;

use TSH::Log;
use TSH::Utility;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::ResultsByRound - implement the C<tsh> ResultsByRound command

=head1 SYNOPSIS

  my $command = new TSH::Command::ResultsByRound;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::ResultsByRound is a subclass of TSH::Command.

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
Use this command to display standings in a division
based on a range of rounds
(e.g. 1-7, 5, 12-14), typically to determine special prizes.
EOF
  $this->{'names'} = [qw(rbr resultsbyround)];
  $this->{'argtypes'} = [qw(RoundRange Divisions)];
# print "names=@$namesp argtypes=@$argtypesp\n";

  return $this;
  }

sub new ($) { return TSH::Utility::new(@_); }

=item $command->Run($tournament, @parsed_args)

Should run the command in the context of the given
tournament with the specified parsed arguments.

=cut

# TODO: split this up into smaller subs for maintainability

sub Run ($$@) { 
  my $this = shift;
  my $tournament = shift;
  my ($r0, $r1, $dp) = @_;
  $dp->CheckRoundHasResults($r1-1) or return 0;
# $dp->ComputeRanks($r0-2); # 20180105
  $dp->ComputeRanks($r0-2);
  $dp->ComputeRanks($r1-1);
  my $config = $tournament->Config();
  my $termsp = $config->Terminology({map {$_ => []} qw(New_Rank New_Rk Player Previous_Rank Prv Rank Rating Rnk Rtng Spread Won_Lost)});

  my $logp = new TSH::Log($tournament, $dp, 'standings', "$r0-$r1", {
    'title' => $config->Terminology('PartialResultsTitle', $dp->Name(), $r0, $r1),
    });
  $logp->ColumnClasses([qw(rank rank wl spread rating name)]);
  $logp->ColumnTitles({
    'text'=> [map { $termsp->{$_} } qw(Rnk Prv New_Rk Won_Lost Spread Rtng Player)],
    'html' => [map { $termsp->{$_} } qw(Rank Previous_Rank New_Rank Won_Lost Spread Rating Player)],
    });
  $r0--;
  $r1--;
  for my $p ($dp->Players()) {
    $p->{tlosses} = $p->RoundLosses($r1) - $p->RoundLosses($r0-1);
    $p->{twins} = $p->RoundWins($r1) - $p->RoundWins($r0-1);
    $p->{tspread} = $p->RoundSpread($r1) - $p->RoundSpread($r0-1);
    }
  
  my $last_spread = 0;
  my $last_losses = -1;
  my $last_wins = -1;
  my $rank = 0;
  my $n = 0;
  for my $p (sort { $b->{twins}<=>$a->{twins}||
      $a->{tlosses}<=>$b->{tlosses} ||
      $b->{tspread}<=>$a->{tspread} } 
    $dp->Players()) {
    next unless $p->Active();
    $n++;
    if ($p->{tspread} != $last_spread || $p->{twins} != $last_wins
    || $p->{tlosses} != $last_losses) {
      $rank = $n;
      $last_spread = $p->{tspread};
      $last_wins = $p->{twins};
      $last_losses = $p->{tlosses};
      }
    my $prev = $p->RoundRank($r0-1);
    my $curr = $p->RoundRank($r1);
    $logp->WriteRow([
      $rank,
      $prev,
      $curr,
      sprintf("%.1f-%.1f", $p->{twins}, $p->{tlosses}),
      sprintf("%+d", $p->{tspread}),
      $p->Rating(),
      (TSH::Utility::TaggedName $p),
      ]);
    }
  $logp->Close();
  0;
  }

=back

=cut

=head1 BUGS

Only one log file is kept per division.

Should arguably not include inactive players.

Should not mess directly with temporary variables in Player.pm.

=cut


1;
