#!/usr/bin/perl

# Copyright (C) 2005-2018 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::Command::Show12;

use strict;
use warnings;

use TSH::Log;
use TSH::Utility;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::Show12 - implement the C<tsh> SHOW12 command

=head1 SYNOPSIS

  my $command = new TSH::Command::Show12;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::Show12 is a subclass of TSH::Command.

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
Use this command to display a chart of who has gone
first (started) or second (replied) in each round.
EOF
  $this->{'names'} = [qw(show12)];
  $this->{'argtypes'} = [qw(Division)];
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
  my $dp = shift;
  my $config = $tournament->Config();

  my $session_breaks = $config->Value('session_breaks') || [];
  my %session_breaks;
  return 0 unless defined $config->CheckRequiredValues(qw(track_firsts));
  my $max_round0 = $dp->MaxRound0();
  if (!defined $max_round0) {
    $tournament->TellUser('eneed_max_rounds');
    return 0;
    }
  my $max_rounds = $max_round0 + 1;

  $dp->SynchFirsts(); # just in case
  my $logp = new TSH::Log($tournament, $dp, 'firsts', undef,
    { 'titlename' => 'Firsts and Seconds' }
    );
  my (@titles) = qw(player_num Player 1st 2nd Record_of_Firsts_and_Seconds);
  my $t = $config->Terminology( { map {$_=>[]} @titles } );
  (@titles) = map { $t->{$_} } @titles;
  my (@classes) = qw(id name p12 p12 p12record);
  if (@$session_breaks) {
    $logp->ColumnAttributes(['', '', '', '', "colspan=".(@$session_breaks+1)]);
    for my $r1 (@$session_breaks) {
      $session_breaks{$r1} = 1;
      }
    }
  $logp->ColumnClasses(\@classes);
  $logp->ColumnTitles( {
    'text' => \@titles,
    'html' => \@titles,
    } );
  if (@$session_breaks) {
    for my $i (1..@$session_breaks) {
      push(@classes, 'p12record');
      }
    $logp->ColumnAttributes([]);
    $logp->ColumnClasses(\@classes);
    }

  for my $p ($dp->Players()) {
    next unless $p->Active();
    my @data;
    push(@data, $p->ID(), $p->PrettyName(), $p->Firsts(), $p->Seconds(), '');
    for my $r1 (1..$max_rounds) {
      my $p12 = $p->First($r1-1);
      $data[-1] .= ('-', '1', '2', '?', '.')[$p12] || '!';
      if ($session_breaks{$r1}) {
	push(@data, '');
        }
      }
    $logp->WriteRow([@data[0..3],join(' ', @data[4..$#data])], \@data);
    }
  $logp->Close();
  }

=back

=cut

=head2 BUGS

None known.

=cut

1;
