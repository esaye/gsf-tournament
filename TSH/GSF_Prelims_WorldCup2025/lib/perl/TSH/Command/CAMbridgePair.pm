#!/usr/bin/perl

# Copyright (C) 2005 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::CAMbridgePair;

use strict;
use warnings;

use TSH::Utility;
use TSH::Division::Pairing::Clark;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::CAMbridgePair - implement the C<tsh> CAMbridgePair command

=head1 SYNOPSIS

  my $command = new TSH::Command::CAMbridgePair;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::CAMbridgePair is a subclass of TSH::Command.

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
Use this command to compute the fixed portion of 
the seven-round pairings for the Cambridge, ON
tournament.
EOF
  $this->{'names'} = [qw(camp cambridgepair)];
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
  my ($dp) = @_;
  if ($dp->LastPairedRound0() != -1) 
    { TSH::Utility::Error "Division already has pairings.\n"; return; }
  print "Calculating Cambridge pairings for Division $dp->{'name'}.\n";

  my $datap = $dp->{'data'};
  if ($#$datap == 6) { for my $i (6,5,4,3,2) { TSH::Division::Pairing::Clark::Pair $dp, $i; } }
  elsif ($#$datap == 8) { for my $i (8,7,6,5,4,3,2) { TSH::Division::Pairing::Clark::Pair $dp, $i; } }
  elsif ($#$datap == 10) { for my $i (10,8,7,5,4,2) { TSH::Division::Pairing::Clark::Pair $dp, $i; } }
  elsif ($#$datap == 12) { for my $i (12,10,8,6,4,2) { TSH::Division::Pairing::Clark::Pair $dp, $i; } }
  elsif ($#$datap == 14) { for my $i (14,12,10,8,4,2) { TSH::Division::Pairing::Clark::Pair $dp, $i; } }
  elsif ($#$datap == 16) { for my $i (16,14,11,8,5,2) { TSH::Division::Pairing::Clark::Pair $dp, $i; } }
  elsif ($#$datap == 18) { for my $i (18,15,12,9,6,3) { TSH::Division::Pairing::Clark::Pair $dp, $i; } }
  elsif ($#$datap == 20) { for my $i (20,17,14,11,8,5){ TSH::Division::Pairing::Clark::Pair $dp, $i; } }
  elsif ($#$datap == 22) { for my $i (22,18,14,10,6,2){ TSH::Division::Pairing::Clark::Pair $dp, $i; } }
  # my generalisation
  elsif ($#$datap % 2 == 0 && $#$datap > 22) {
    my $delta = int($#$datap / 6);
    my $opp1 = $#$datap;
    for my $i (1..6) {
      TSH::Division::Pairing::Clark::Pair $dp, $opp1;
      $opp1 -= $delta;
      }
    }
  else {
    TSH::Utility::Error "Don't know how to do Cambridge pairings for this division size.\n";
    }
  $dp->Dirty(1);
  $this->Processor()->Flush();
  }

=back

=cut

=head1 BUGS

This command has not yet been updated to support the etc/off flag
labelling inactive players.

=cut


1;
