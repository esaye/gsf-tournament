#!/usr/bin/perl

# Copyright (C) 2016-2019 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::Command::ADdPlayer;

use strict;
use warnings;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::ADdPlayer - implement the C<tsh> ADdPlayer command

=head1 SYNOPSIS

  my $command = new TSH::Command::ADdPlayer;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::ADdPlayer is a subclass of TSH::Command.

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
Use this command to permanently add a player to your tournament,
specifying a division name (in a multi-division event), player
number, full name as it should appear in the player roster, and
optionally pretournament rating.  You may then wish to use the
EditScores command to enter additional information about the player.
EOF
  $this->{'names'} = [qw(adp addplayer)];
  $this->{'argtypes'} = [qw(Division NewPlayerNumber Name OptionalInteger)];
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
  my ($dp, $id, @name) = @_;
  my $rating = 0;
  $rating = pop @name if $name[-1] =~ /^-?\d+$/;

  my $p = $dp->AddPlayer('name' => "@name", 'rating' => $rating);
  $dp->RenumberPlayer($p->ID(), $id); # can throw error to Processor
  $this->Processor()->Flush();
  $tournament->TellUser('iadpok', $p->Name(), $p->ID(), $dp->Name());
  }

=back

=cut

1;

