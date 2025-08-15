#!/usr/bin/perl

# Copyright (C) 2007 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::SPITroast;

use strict;
use warnings;

use TSH::Log;
use TSH::Utility;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::SPITroast - implement the C<tsh> SPITroast command

=head1 SYNOPSIS

  my $command = new TSH::Command::SPITroast;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::SPITroast is a subclass of TSH::Command.

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
Use the SPITroast command to list current standings in a British
rotisserie pool (or "spit roast"), configured using "config spitfile".
EOF
  $this->{'names'} = [qw(spitroast spit)];
  $this->{'argtypes'} = [qw(BasedOnRound Division)];
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
  my ($round, $dp) = @_;
  my $round0 = $round - 1;
  $dp->ComputeRanks($round0);
  my $config = $tournament->Config();
  my $spitfile = $config->Value('spitfile');
  unless ($spitfile && ref($spitfile) eq 'HASH') 
    { $tournament->TellUser('espitcfg'); return; }
  my $dname = $dp->Name();
  $spitfile = $spitfile->{$dname};
  unless ($spitfile) { $tournament->TellUser('espitcfg'); return; }
  my $fn = $config->MakeRootPath($spitfile);
  my $fh = TSH::Utility::OpenFile("<", $fn);
  unless ($fh) { $tournament->TellUser('espitope', $fn, $!); return; }
  local($/);
  my $slurp = <$fh>;
  close($fh);
  my @teams;
  my %team_names;
  my $nplayers = $dp->CountPlayers();
  my (@ranks);
  for my $pn (1..$nplayers) {
    $ranks[$pn] = $dp->Player($pn)->RoundRank($round0);
    }
  for my $line (split(/[\012\015\r\n]+/, $slurp)) {
    $line =~ s/^\s+//; $line =~ s/\s+$//;
    next unless $line =~ /\S/;
    next if $line =~ /^#/;
    my ($picks, $owner, $team) = split(/\s*;\s*/, $line, 3);
    unless (defined $team) { $tournament->TellUser('espitsyn', $line); return; }
    if ($team_names{$team}++) 
      { $tournament->TellUser('espit2t', $team); return; }
    my (@picks) = split(/\s+/, $picks);
    my @pick_counts;
    my $score = 0;
    for my $picki (0..$#picks) {
      my $pick = $picks[$picki];
      $score += abs($ranks[$pick] - ($picki+1));
#     warn "$picki ".abs($ranks[$pick] - ($picki+1)) . "\n";
      if ($pick =~ /\D/ || $pick < 1 || $pick > $nplayers) 
	{ $tournament->TellUser('espitbp', $team, $pick); return; }
      if ($pick_counts[$pick]++) 
	{ $tournament->TellUser('espit2p', $team, $pick); return; }
      }
    for my $pick (1..$nplayers) {
      unless ($pick_counts[$pick]) 
	{ $tournament->TellUser('espitmp', $team, $pick); return; }
      }
    push(@teams, { 'picks' => \@picks, 'owner' => $owner, 'team' => $team,
      'score' => $score});
    }

  my $logp = new TSH::Log($tournament, $dp, 'spit', $round, {
    'title' => "Division $dname Rotisserie Standings After Round $round",
    });
  $logp->ColumnTitles({
    'text' => [qw(Rank Score Picks Owner Team)],
    'html' => [qw(Rank Score Picks Owner Team)],
    });
  $logp->ColumnClasses([qw(rank score picks spittowner spitteam)]);
  @teams = sort { 
    $a->{'score'} <=> $b->{'score'} 
    || $a->{'team'} cmp $b->{'team'} } @teams;
  my $lastscore = -1;
  my $rank = -1;
  for my $i (0..$#teams) {
    my $team = $teams[$i];
    if ($lastscore != $team->{'score'}) {
      $rank = $i + 1;
      $lastscore = $team->{'score'};
      }
    my (@columns) = ($rank, $team->{'score'}, join(' ', @{$team->{'picks'}}),
      $team->{'owner'}, $team->{'team'});
    $logp->WriteRow(\@columns, \@columns);
    }
  $logp->Close();
  }

=back

=cut

1;
