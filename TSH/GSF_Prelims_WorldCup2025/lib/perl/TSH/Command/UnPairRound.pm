#!/usr/bin/perl

# Copyright (C) 2005-2018 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::Command::UnPairRound;

use strict;
use warnings;

use TSH::Utility qw(Debug DebugOn);

# DebugOn('SP');

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::UnPairRound - implement the C<tsh> UnPairRound command

=head1 SYNOPSIS

  my $command = new TSH::Command::UnPairRound;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::UnPairRound is a subclass of TSH::Command.

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
Use this command to delete the pairings for the specified round
and division.
EOF
  $this->{'names'} = [qw(upr unpairround)];
  $this->{'argtypes'} = [qw(Round Division)];
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
  my $config = $tournament->Config();

  if ($dp->LastPairedRound0() == -1) {
    $tournament->TellUser('euprnop', $dp->Name());
    return;
    }

  unless ($config->Value('allow_gaps')) {
    if ($dp->LastPairedRound0() != $round0) {
      $tournament->TellUser('euprwrr', $dp->LastPairedRound0()+1);
      return;
      }
    if ($dp->LastPairedScoreRound0() >= $round0) {
      $tournament->TellUser('euprhass', $round,
	$dp->MostScoresPlayer()->TaggedName());
      return;
      }
    }

  $tournament->TellUser('iuprok', $dp->Name(), $round);
  for my $p ($dp->Players()) {
    next unless $p->Active();
    $p->UnpairRound($round0);
    }
  $dp->PurgeReportsByRound0( $round0 );
  $dp->Dirty(1);
  $this->Processor()->Flush();
  $tournament->TellUser('idone');

  return 0;
  }


=back

=cut

=head1 BUGS

Should perhaps allow deleting rounds whose only scores recorded
are bye spreads.

=cut

1;

