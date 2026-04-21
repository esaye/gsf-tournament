#!/usr/bin/perl

# Copyright (C) 2007 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::CheckRoundScores;

use strict;
use warnings;

use TSH::Log;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::CheckRoundScores - implement the C<tsh> CheckRoundScores command

=head1 SYNOPSIS

  my $command = new TSH::Command::CheckRoundScores;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::CheckRoundScores is a subclass of TSH::Command.

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
Use this command to list all the scored entered for a division
in a round, to check that they were entered correctly.
EOF
  $this->{'names'} = [qw(crs checkroundscores)];
  $this->{'argtypes'} = [qw(Round Division)];
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
  my ($r1, $dp) = @_;
  my $r0 = $r1 - 1;
  my $config = $tournament->Config();

  my $logp = new TSH::Log($tournament, $dp, 'scores', $r0+1);
  $logp->ColumnClasses([qw(name name score name name score spread)]);
  $logp->ColumnTitles(
    {
    'text' => [map { $config->Terminology($_) } qw(Player player_ID Score Player player_ID Score Sprd)],
    'html' => [map { $config->Terminology($_) } qw(Player player_ID Score Player player_ID Score Spread)],
    }
    );
  
  # which player is listed in column 1
  my $mode = 
    ($config->Value('track_firsts') && (!$config->Value('check_by_winner')))
      ? 'first'
      : 'winner';

  my $bye_term = $config->Terminology('bye');
  my $unpaired_term = $config->Terminology('unpaired');

  for my $p ($dp->Players()) {
    if ($mode eq 'first') {
      next if $p->First($r0) == 2;
      }
    my $mid = $p->ID();
    my $ms = $p->Score($r0) || 0;
    my $os = 0;
    my $oid;
    my $opp = $p->Opponent($r0);
    if ($opp) {
      $os = $opp->Score($r0) || 0;
      $oid = $opp->ID();
      }
    elsif (!$p->Active()) {
      next;
      }
    if ($mode eq 'winner') {
      next if $oid && $ms < $os;
      }
    my $on = $opp ? $opp->Name() : (defined $oid) ? $bye_term : $unpaired_term;
    $logp->WriteRow([$p->Name(), $mid, $ms, $on, $oid // 0, $os, $ms-$os]);
    }
  $logp->Close();
  return 0;
  }

=back

=cut

=head1 BUGS

None known.

=cut

1;
