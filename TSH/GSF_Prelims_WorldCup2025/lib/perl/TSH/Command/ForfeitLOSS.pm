#!/usr/bin/perl

# Copyright (C) 2010 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::ForfeitLOSS;

use strict;
use warnings;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::ForfeitLOSS - implement the C<tsh> ForfeitLOSS command

=head1 SYNOPSIS

  my $command = new TSH::Command::ForfeitLOSS;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::ForfeitLOSS is a subclass of TSH::Command.

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
Use the ForfeitLOSS command to assign a forfeit loss to a player in a given round.
If they had an opponent, their opponent will be assigned a forfeit win.
You can specify the magnitude of the spread (as a positive number)
associated with the loss; if you do not,
it will default to the value of the bye_spread configuration parameter.
EOF
  $this->{'names'} = [qw(floss forfeitloss)];
  $this->{'argtypes'} = [qw(Division Player Round OptionalInteger)];
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
  my ($dp, $pid, $round, $spread) = @_;
  my $p = $dp->Player($pid);
  my $r0 = $round - 1;
  $spread = $tournament->Config()->Value('bye_spread') unless defined $spread;
  if ($spread < 0) {
    warn "Spread must be nonnegative.\n";
    return;
    }
  if (my $opp = $p->Opponent($r0)) {
    if (($opp->OpponentID($r0)||0) == $pid) {
      return unless $dp->Pair($opp->ID(), 0, $r0, 'repair');
      $opp->Score($r0, $spread);
      }
    else { # opponent somehow already got paired with someone else
      $tournament->TellUser('enfwop', $pid, $opp->ID(), $opp->OpponentID($r0));
      }
    }
  return unless $dp->Pair($pid, 0, $r0, 'repair');
  $p->Score($r0, -$spread);
  $this->Processor()->Flush();
  }

=back

=cut

=head1 BUGS

None known.

=cut

1;
