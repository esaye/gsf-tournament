#!/usr/bin/perl

# Copyright (C) 2007 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::ShowManyPairings;

use strict;
use warnings;

use TSH::Log;
use TSH::Utility qw(Debug DebugOn);
use TSH::Command::ShowPairings;

# DebugOn('SP');

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::ShowManyPairings - implement the C<tsh> ShowManyPairings command

=head1 SYNOPSIS

  my $command = new TSH::Command::ShowManyPairings;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::ShowManyPairings is a subclass of TSH::Command.

=cut

=head1 DESCRIPTION

=over 4

=cut

sub initialise ($$$$);
sub new ($);
sub Run ($$@);
sub ShowHeader ($$$$$);
sub ShowPlayer ($$$$$$$);

=item $parserp->initialise()

Used internally to (re)initialise the object.

=cut

sub initialise ($$$$) {
  my $this = shift;
  my $path = shift;
  my $namesp = shift;
  my $argtypesp = shift;

  $this->{'help'} = <<'EOF';
Use this command to display the pairings for the specified division
and range of rounds.
EOF
  $this->{'names'} = [qw(smp showmanypairings)];
  $this->{'argtypes'} = [qw(RoundRange Division)];
# print "names=@$namesp argtypes=@$argtypesp\n";

  return $this;
  }

sub new ($) { return TSH::Utility::new(@_); }

=item $command->Run($tournament, @parsed_args);

Should run the command in the context of the given
tournament with the specified parsed arguments.

=cut

sub Run ($$@) { 
  my $this = shift;
  my $tournament = shift;
  my ($firstr1, $lastr1, $dp) = @_;
  return if $firstr1 > $lastr1;
  my $firstr0 = $firstr1-1;
  my $lastr0 = $lastr1-1;

  if (0) { # 2012-09-07
    my $last_score_round0 = $dp->MostScores() - 1;
    # check for autopairing and board assignment in each round
    for my $r1 ($firstr1..$lastr1) {
      $dp->CheckAutoPair($this->Processor(), $r1);
      my $sr0 = $r1 - 2;
      $sr0 = $last_score_round0 if $sr0 > $last_score_round0;
      $dp->ComputeBoards($sr0, $r1-1);
      }
    }
  else {
    my $dname = $dp->Name();
    for my $r1 ($firstr1..$lastr1) {
      $this->Processor()->Process("sp $r1 $dname");
      }
    }

  # any pairings to show?
  if ($lastr0 > $dp->LastPairedRound0()) {
    $tournament->TellUser('enopryet', $dp->Name(), $lastr1);
    return;
    }
  my $logp = new TSH::Log($tournament, $dp, 'multipair', "$firstr1-$lastr1",
    { 'title' => "Division ".$dp->Name()." Pairings: Round"
      . ($firstr1 == $lastr1 ? " $firstr1" : "s $firstr1-$lastr1")});
  my ($text_classes, $html_classes) 
    = $this->ShowHeader($dp, $logp, $firstr1, $lastr1);
  for my $p ($dp->Players()) {
    $this->ShowPlayer($logp, $p, $firstr0, $lastr0,
      $text_classes, $html_classes);
    }
  $logp->Close();
  $this->Processor()->Flush(); # in case table numbers were changed
  }

=item $command->ShowHeader($division, $log, $first_round1, $last_round1);

Used internally to show the header of the pairings listings

=cut

sub ShowHeader ($$$$$) {
  my $this = shift;
  my $dp = shift;
  my $tournament = $dp->Tournament();
  my $logp = shift;
  my $first_round1 = shift;
  my $last_round1 = shift;
  my $config = $tournament->Config();
  my $tables = $config->Value('tables');
  $tables = $tables->{$dp->Name()} if $tables;
  my $assign_firsts = $config->Value('assign_firsts');
  my $track_firsts = $config->Value('track_firsts');
  my $noboards = $config->Value('no_boards');
  my $hastables = $dp->HasTables();
  my $has_boards_or_tables = $hastables || !$noboards;

  my (@attributes) = (undef,undef);
  my (@html_classes) = qw(id name);
  my @text_classes;
  my (@html_titles) = ('#', $config->Terminology('Player'));
  my (@text_titles) = @html_titles;
  my (@attributes2) = (undef,undef);
  my (@html_classes2) = qw(empty);
  my (@html_titles2) = ('');

  if ($track_firsts) {
    push(@html_titles, $config->Terminology('Firsts'), $config->Terminology('Seconds'));
    push(@text_titles, $config->Terminology('1st'), $config->Terminology('2nd'));
    push(@html_classes, qw(firsts firsts));
    push(@attributes, undef, undef);
    @attributes2 = ('colspan=4');
    }
  else {
    @attributes2 = ('colspan=2');
    }
  @text_classes = @html_classes;
  my $entry_columns = 1;
  $entry_columns++ if $assign_firsts;
  $entry_columns++ if $has_boards_or_tables;
  for my $r1 ($first_round1..$last_round1) {
    push(@attributes, "colspan=$entry_columns");
    push(@html_classes, 'round');
    push(@html_titles, "Rd. $r1");

    push(@text_classes, "multipair");
    push(@text_titles, "R$r1");

    push(@html_classes2, "opp");
    push(@html_classes2, "p12") if $assign_firsts;
    push(@html_classes2, $tables ? 'table' : 'board') if $has_boards_or_tables;
    push(@html_titles2, $config->Terminology('Opp'));
    push(@html_titles2, $config->Terminology('1/2')) if $assign_firsts;
    push(@html_titles2, $tables ? $config->Value('table_title') || $config->Terminology('Table') : $config->Terminology('Board')) if $has_boards_or_tables;
    }

  $logp->ColumnAttributes(\@attributes);
  $logp->ColumnClasses(\@text_classes);
  $logp->WriteTitle(\@text_titles, []);
  $logp->ColumnClasses(\@html_classes);
  $logp->WriteTitle([], \@html_titles);
  $logp->ColumnAttributes(\@attributes2);
  $logp->ColumnClasses(\@html_classes2);
  $logp->WriteTitle([], \@html_titles2);
  $logp->ColumnAttributes([]);
  shift(@html_classes2);
  unshift(@html_classes2, qw(id name firsts firsts));
  return (\@text_classes, \@html_classes2);
}

=item $command->ShowPlayer($logp, $player, $firstr0, $lastr0,
  $text_classes, $html_classes);

Used internally to show a row of pairings information for a player.

=cut

sub ShowPlayer ($$$$$$$) {
  my $this = shift;
  my $logp = shift;
  my $p = shift;
  my $firstr0 = shift;
  my $lastr0 = shift;
  my $text_classes = shift;
  my $html_classes = shift;

  my $dp = $p->Division();
  my $tournament = $dp->Tournament();
  my $config = $tournament->Config();
  my $tables = $config->Value('tables');
  my $noboards = $config->Value('no_boards');
  my $bye_term = $config->Terminology('Bye');
  $tables = $tables->{$dp->Name()} if $tables;
  my $has_boards_or_tables = $tables || !$noboards;

  my (@text_data) = ($p->ID(), $p->PrettyName());
  my (@html_data);

  if ($config->Value('track_firsts')) {
    my (@p12) = (0,0,0,0,0);
    for my $r0 (0..$firstr0-1) { $p12[$p->First($r0)]++; }
    push(@text_data, ($p12[1]||0), ($p12[2]||0));
    }
  @html_data = @text_data;

  my $assign_firsts = $config->Value('assign_firsts');
  for my $r0 ($firstr0..$lastr0) {
    my $oid = $p->OpponentID($r0);
    my $p12 = $p->First($r0); $p12 =~ s/[^12]/ /;
    if (!defined $oid) { # unpaired
      push(@text_data, '-');
      push(@html_data, '&nbsp;'); # opp
      push(@html_data, '&nbsp;') if $assign_firsts;
      push(@html_data, '&nbsp;') if $has_boards_or_tables; # board/table
      }
    elsif (!$oid) { # bye
      push(@text_data, $bye_term);
      push(@html_data, $bye_term); # opp
      push(@html_data, '&nbsp;') if $assign_firsts;
      push(@html_data, '&nbsp;') if $has_boards_or_tables; # board/table
      }
    else {
      my $board = $p->Board($r0);
      my $table = $tables ? $tables->[$board-1] : $board;
      my $text = $oid;
      $text .= "#$p12" if $assign_firsts;
      $text .= "\@$table" if $has_boards_or_tables;
      push(@text_data, $text);
      push(@html_data, $oid);
      push(@html_data, $p12) if $assign_firsts;
      push(@html_data, $table) if $has_boards_or_tables;
      }
    }

  $logp->ColumnClasses($text_classes);
  $logp->WriteRow(\@text_data, []);
  $logp->ColumnClasses($html_classes);
  $logp->WriteRow([], \@html_data);
  }

=back

=cut

=head1 BUGS

None known.

=cut

1;
