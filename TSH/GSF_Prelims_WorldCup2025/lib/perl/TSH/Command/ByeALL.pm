#!/usr/bin/perl

# Copyright (C) 2019 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::Command::ByeALL;

use strict;
use warnings;

use TSH::Utility;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::ByeALL - implement the C<tsh> ByeALL command

=head1 SYNOPSIS

  my $command = new TSH::Command::ByeALL;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::ByeALL is a subclass of TSH::Command.

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
This command assigns byes to all unpaired players in a division in a round.
EOF
  $this->{'names'} = [qw(byeall ball)];
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
  my $r0 = $round - 1;
  my $bye_spread = $dp->GetConfigValue('bye_spread');

  for my $p ($dp->Players()) {
    next if defined $p->OpponentID($r0);
#   warn "giving explicit bye to $p->{id}, pairings: @{$p->{pairings}}";
    $dp->Pair($p->ID(), 0, $r0);
    $p->Score($r0, $bye_spread);
    }
  $dp->Dirty(1);
  $dp->DirtyRound($r0);
  $this->Processor()->Flush();
  }

=back

=cut

=head1 BUGS

This command should be removed from C<tsh>.

Opponents of the new bye player should be assigned byes.

=cut

1;
