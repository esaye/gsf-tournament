#!/usr/bin/perl

# Copyright (C) 2019 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::Command::UnPairPlayer;

use strict;
use warnings;

use TSH::Utility qw(Debug DebugOn);

# DebugOn('SP');

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::UnPairPlayer - implement the C<tsh> UnPairPlayer command

=head1 SYNOPSIS

  my $command = new TSH::Command::UnPairPlayer;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::UnPairPlayer is a subclass of TSH::Command.

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
Use this command to unpair a player in the specified
round and division.
EOF
  $this->{'names'} = [qw(upr unpairround)];
  $this->{'argtypes'} = [qw(Player Round Division)];
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
  my ($pn, $round, $dp) = @_;
  my $round0 = $round - 1;
  my $config = $tournament->Config();

  $tournament->TellUser('iuprok', $dp->Name(), $round);
  my $p = $dp->Player($pn);
  $p->UnpairRound($round0);
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

