#!/usr/bin/perl

# Copyright (C) 2016-2019 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::Command::ReMovePlayer;

use strict;
use warnings;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::ReMovePlayer - implement the C<tsh> ReMovePlayer command

=head1 SYNOPSIS

  my $command = new TSH::Command::ReMovePlayer;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::ReMovePlayer is a subclass of TSH::Command.

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
Use this command to permanently remove a player from your tournament.
EOF
  $this->{'names'} = [qw(rmp removeplayer)];
  $this->{'argtypes'} = [qw(Division Player)];
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
  my ($dp, $id, $round) = @_;
  my $datap = $dp->{'data'};
  my $p = $dp->Player($id);
  my $name = $p->Name();

  unless (defined $p) { 
    $tournament->TellUser('ebadp', $id);
    return 0;
    }

  $dp->DeletePlayer($id); # can throw error to Processor
  $this->Processor()->Flush();
  $tournament->TellUser('irmpok', $name, $id, $dp->Name());
  }

=back

=cut

1;

