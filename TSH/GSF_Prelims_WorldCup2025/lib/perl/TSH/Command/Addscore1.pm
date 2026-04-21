#!/usr/bin/perl

# Copyright (C) 2018 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::Command::Addscore1;

use strict;
use warnings;

use TSH::Utility;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::Addscore1 - implement the C<tsh> Addscore1 command

=head1 SYNOPSIS

  my $command = new TSH::Command::Addscore1;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::Addscore1 is a subclass of TSH::Command.

=cut

=head1 DESCRIPTION

=over 4

=cut

sub initialise ($$);
sub new ($$);
sub Run ($$@);

=item $parserp->initialise($processor)

Used internally to (re)initialise the object.

=cut

sub initialise ($$) {
  my $this = shift;

  $this->SUPER::initialise(@_);
  $this->{'help'} = <<'EOF';
Use this command to add a single score from the command line.
This command is intended primarily for scripted use.
EOF
  my $config = $this->Processor()->Tournament()->Config();
  $this->{'names'} = [qw(addscore1 a1)];
  $this->{'argtypes'} = 
    $config->Value('entry') eq 'spread'
      ? [qw(PlayerOrZero PlayerOrZero Spread Round Division)]
      : [qw(PlayerOrZero Score PlayerOrZero Score Round Division)];
  return $this;
  }

sub new ($$) { return TSH::Utility::new(@_); }

=item $command->Run($tournament, @parsed_args)

Should run the command in the context of the given
tournament with the specified parsed arguments.

=cut

# TODO: split this up into smaller subs for maintainability

sub Run ($$@) { 
  my $this = shift;
  my $tournament = shift;
  my $config = $tournament->Config();
  my ($pn1, $s1, $pn2, $s2, $round, $dp);
  warn "This command is not yet implemented.\n"; return 0;
  # The rest appears to have been copied from DELETEscore command, but
  # not adapted/updated.  We then copied this to AddProvisionalScore,
  # so further development here should copy any changes back from there.
  if ($config->Value('entry') eq 'spread') {
    $s2 = 0;
    ($pn1, $pn2, $s1, $round, $dp) = @_;
    }
  else {
    ($pn1, $s1, $pn2, $s2, $round, $dp) = @_;
    }
  my $round0 = $round - 1;

  if ($pn1 == 0) { ($pn1, $pn2, $s1, $s2) = ($pn2, $pn1, $s2, $s1); }
  my $pp1 = $dp->Player($pn1);
  unless ($pp1) { $tournament->TellUser('enosuchp', $pn1); return; }
  my $ps1 = $pp1->Score($round0);
  if (0 == $pp1->OpponentID($round0)) { # bye
    if ($pn2) {
      $tournament->TellUser('edeletewasbye', $pp1->TaggedName(), $round);
      return;
      }
    if ($ps1 != $s1) {
      $tournament->TellUser('edeletewrongscore', $pp1->TaggedName(), $ps1, $s1);
      return;
      }
    if ($dp->DeleteByeScore($pn1, $round0)) {
      $tournament->TellUser('idone');
      $dp->Dirty(1);
      $dp->DirtyRound($round0);
      $this->Processor()->Flush();
      }
    return;
    }
  elsif (0 == $pn2) {
    $tournament->TellUser('edeletenotbye', $pp1->TaggedName(), $round);
    return;
    }
  my $pp2 = $dp->Player($pn2);
  unless ($pp2) { $tournament->TellUser('enosuchp', $pn2); return; }
  my $ps2 = $pp2->Score($round0);
  if (($pp1->OpponentID($round0)||-1) ne $pn2) {
    $tournament->TellUser('edeletewrongpair', $pp1->TaggedName(), $pp2->TaggedName(), $round);
    return;
    }
  if ($ps1 != $s1) {
    $tournament->TellUser('edeletewrongscore', $pp1->TaggedName(), $ps1, $s1);
    return;
    }
  if ($ps2 != $s2) {
    $tournament->TellUser('edeletewrongscore', $pp2->TaggedName(), $ps2, $s2);
    return;
    }
  if ($dp->DeleteScores($pn1, $pn2, $round0)) {
    $tournament->TellUser('idone');
    $dp->Dirty(1);
    $dp->DirtyRound($round0);
    $this->Processor->Flush();
    }
  }

=back

=cut

=head1 BUGS

You should be able to delete a bye, either with this command or
another similar one, but you can't.

=cut

1;
