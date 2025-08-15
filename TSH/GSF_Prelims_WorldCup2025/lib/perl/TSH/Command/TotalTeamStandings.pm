#!/usr/bin/perl

# Copyright (C) 2005-2015 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::Command::TotalTeamStandings;

use strict;
use warnings;

use TSH::Log;
# use TSH::Utility qw(Debug DebugOn);

# DebugOn('SP');

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::TotalTeamStandings - implement the C<tsh> TotalTeamStandings command

=head1 SYNOPSIS

  my $command = new TSH::Command::TotalTeamStandings;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::TotalTeamStandings is a subclass of TSH::Command.

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
Use this command to display total team standings.
EOF
  $this->{'names'} = [qw(tts totalteamstandings)];
  $this->{'argtypes'} = [qw()];
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

  my $rankround0 = -1;
  my $round = 0;
  for my $dp ($tournament->Divisions()) {
    my $dround = $dp->MostScores();
    $round = $dround if $dround > $round;
    $dround = $dp->LeastScores()-1;
    $dp->ComputeRanks($dround);
    $rankround0 = $dround if $dround > $rankround0;
    }
  my $logp = new TSH::Log($tournament, undef, 'total_teams', $round);
  $logp->ColumnClasses([qw(rank wl spread wl spread wl spread name ranks)]);
  $logp->ColumnTitles(
    {
      'text' => ['Rnk', '  Won-Lost', 'Spread', ' Mean-WL',  qw(Mean-Spr W%VsO Team Mean-Rk Ranks)],
      'html' => [qw(Rank Won-Lost Spread Mean-WL Mean<br>Spread), 'Winning %<br>vs. Others', qw(Team Mean-Rank Ranks)],
    }
    );

  my %teams;
  for my $dp ($tournament->Divisions()) {
    $dp->CountTeamRecords($round-1, $rankround0, \%teams);
    }

  my $lastw = -1; my $lasts = 0; my $rank = 0; my $i = 0; my $lastl = -1;
  for my $teamname (sort { 
    # total games played including vs teammates
    my $ac = $teams{$a}{'count'};
    my $bc = $teams{$b}{'count'};
    # games played excluding vs teammates; capped || uncapped
    my $axc = $teams{$a}{'xccount'} || $teams{$a}{'xcount'};
    my $bxc = $teams{$b}{'xccount'} || $teams{$b}{'xcount'};
    ($bxc ? ($teams{$b}->{'xcwins'}||$teams{$b}->{'xwins'})/$bxc : 0)
      <=> ($axc ? ($teams{$a}->{'xcwins'}||$teams{$a}->{'xwins'})/$axc : 0)
    || $teams{$b}->{'wins'}/$bc <=> $teams{$a}->{'wins'}/$ac
    || $teams{$a}->{'losses'}/$ac <=> $teams{$b}->{'losses'}/$bc
    || $teams{$b}->{'spread'}/$bc <=> $teams{$a}->{'spread'}/$ac
    } keys %teams) {
    my $teamdata = $teams{$teamname};
    $teamdata->{'xcount'} ||= 0;
    my $wins = $teamdata->{xcwins} || $teamdata->{'wins'};
    my $losses = $teamdata->{xclosses} || $teamdata->{'losses'};
    my $spread = $teamdata->{xcspread} || $teamdata->{'spread'};
    my $count = $teamdata->{'xccount'} || $teamdata->{'count'};
    my $ranks = $teamdata->{xcranks} || $teamdata->{'ranks'};
    my $ranksum = $teamdata->{xcranksum} || $teamdata->{ranksum};
    # not including vs teammates
    my $xwins = $teamdata->{xcwins} || $teamdata->{xwins};
    my $xcount = $teamdata->{xccount} || $teamdata->{xcount};
#   warn "$xwins / $teamdata->{xccount}||$teamdata->{xcount}";
    $i++;
    if ($wins != $lastw || $spread != $lasts || $losses != $lastl) {
      $lastl = $losses;
      $lastw = $wins; $lasts = $spread;
      $rank = $i;
      }
    $logp->WriteRow([
      $rank,
      sprintf("%5.1f-%5.1f", $wins, $losses),
      sprintf("%+7.1f", $spread),
      sprintf("%5.2f-%5.2f", @$ranks && $wins/@$ranks, @$ranks && $losses/@$ranks),
      sprintf("%+6.1f", @$ranks && $spread/@$ranks),
#     sprintf("%5.1f-%5.1f", $teamdata->{'xwins'}, $teamdata->{'xlosses'}),
      sprintf("%6.2f", $count && 100*$xwins/$xcount),
      $teamname,
      sprintf("%6.2f", @$ranks && $ranksum/@$ranks),
      join(' ', sort { $a <=> $b } @$ranks),
      ]
    );
    }
  $logp->Close();
  }

=back

=cut

=head1 BUGS

None known

=cut

1;
