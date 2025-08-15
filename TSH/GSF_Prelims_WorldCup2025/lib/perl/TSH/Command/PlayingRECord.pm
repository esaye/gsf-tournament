#!/usr/bin/perl

# Copyright (C) 2019 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::Command::PlayingRECord;

use strict;
use warnings;

use TSH::Log;
use TSH::Utility qw(Debug DebugOn FormatHTMLHalfInteger FormatHTMLInteger FormatHTMLSignedInteger);

# DebugOn('SP');

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::PlayingRECord - implement the C<tsh> PlayingRECord command

=head1 SYNOPSIS

  my $command = new TSH::Command::PlayingRECord;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::PlayingRECord is a subclass of TSH::Command.

=cut

=head1 DESCRIPTION

=over 4

=cut

sub initialise ($@);
sub new ($);
sub RenderDivision ($$);
sub RenderPlayer ($$$$);
sub Run ($$@);
sub SetupOptions ($$$);

=item $parserp->initialise()

Used internally to (re)initialise the object.

=cut

sub initialise ($@) {
  my $this = shift;

  $this->SUPER::initialise(@_);
  $this->{'help'} = <<'EOF';
Use this command to display information about a player's
results (W/L/T/B/A/F/N/U) in each round.
EOF
  $this->{'names'} = [qw(prec playingrecord)];
  $this->{'argtypes'} = [qw(Divisions)];

  return $this;
  }

sub new ($) { return TSH::Utility::new(@_); }

sub RenderDivision ($$) {
  my $dp = shift;
  my $optionsp = shift;

  my $tournament = $dp->Tournament();

  my $session_breaks = $dp->GetConfigValue('session_breaks') || [];
  my $max_rounds = $dp->GetConfigValue('max_rounds');
  unless (defined $max_rounds) {
    $tournament->TellUser('eneed_max_rounds'); return; 
    }

  my $logp = new TSH::Log($tournament, $dp, 
    ($optionsp->{'filename'} || 'playingrecord'),
    undef,
    {
      'noconsole' => $optionsp->{'noconsole'},
      %$optionsp,
    },
    );

  $logp->ColumnClasses([qw(W L T B A F N U), ('session')x(@$session_breaks+1)]);
  $logp->ColumnTitles({
    'text' => [qw(W L T B A F N U Rec)],
    'html' => [qw(Wins Losses Ties Byes Absences Forfeits), 'No Score', 'Unpaired',
      map { "Session $_" } 1..(@$session_breaks+1)],
    });

  for my $p ($dp->Players()) {
    RenderPlayer $logp, $p, $max_rounds, $session_breaks;
    }

  $logp->Close();
  }

=item RenderPlayer($logp, $pp, $maxround, $session_breaks);

Render a row of a ratings table.

=cut

sub RenderPlayer ($$$$) {
  my $logp = shift;
  my $p = shift;
  my $maxround = shift;
  my (@session_breaks) = @{shift||[]};

  my (@session_records) = ('');
  my %counts;

  for my $r0 (0..$maxround-1) {
    if (@session_breaks and $r0 == $session_breaks[0]) {
      shift @session_breaks;
      push(@session_records, '');
      }
    my $ms = $p->Score($r0);
    my $outcome;
    if (my $oid = $p->OpponentID($r0)) {
      my $opp = $p->Opponent($r0);
      my $os = $opp->Score($r0);
      if (defined $ms) {
	if (defined $os) {
	  if ($ms > $os) { $outcome = 'W'; } # win
	  elsif ($ms < $os) { $outcome = 'L'; } # loss
	  else { $outcome = 'T'; } # tie
	  }
	else { $outcome = 'N'; } # no score
	}
      else { $outcome = 'N'; } # no score
      }
    elsif (defined $oid) {
      if (!defined $ms) { $outcome = 'N'; } # no score
      elsif ($ms > 0) { $outcome = 'B'; } # bye 
      elsif ($ms < 0) { $outcome = 'F'; } # forfeit 
      else { $outcome = 'A'; } # absent 
      }
    else { $outcome = 'U'; } # unpaired
    $counts{$outcome}++;
    $session_records[-1] .= $outcome;
    }

    my (@fields) = ((map { $counts{$_} || '' } qw(W L T B A F N U)), @session_records);
    $logp->WriteRow(\@fields, \@fields);
  }

=item $command->Run($tournament, @parsed_args)

Should run the command in the context of the given
tournament with the specified parsed arguments.

=cut

sub Run ($$@) { 
  my $this = shift;
  my $tournament = shift;
  my (@dp) = @_;
  (@dp) = $tournament->Divisions() unless @dp;
  my $config = $tournament->Config();
  my $optionsp = SetupOptions($config, \@dp, $this->{'noconsole'});

  for my $dp (@dp) {
    RenderDivision($dp, $optionsp);
    }

  return 0;
  }

sub SetupOptions ($$$) {
  my $config = shift;
  my $dpp = shift;
  my $noconsole = shift;

  my (%options) = ();
  $options{'noconsole'} = $noconsole;

  return \%options;
  }

=back

=cut

1;
