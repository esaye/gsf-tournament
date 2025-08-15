#!/usr/bin/perl

# Copyright (C) 2011 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::AssignTeamsSnaked;

use strict;
use warnings;

use TSH::PairingCommand;
use TSH::Utility qw(Debug DebugOn DebugOff);

DebugOn('AssignTeamsSnaked');

our (@ISA) = qw(TSH::Command);
our ($pairings_data);

=pod

=head1 NAME

TSH::Command::AssignTeamsSnaked - implement the C<tsh> AssignTeamsSnaked command

=head1 SYNOPSIS

  my $command = new TSH::Command::AssignTeamsSnaked;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::AssignTeamsSnaked is a subclass of TSH::Command.

=cut

=head1 DESCRIPTION

=over 4

=cut

sub initialise ($$$$);
sub new ($);
sub Run ($$@);

sub initialise ($$$$) {
  my $this = shift;
  my $path = shift;
  my $namesp = shift;
  my $argtypesp = shift;

  $this->{'help'} = <<'EOF';
This command can be used to assign all players to two or more
notional teams, for subsequent use in pairings calculations.
Players are assigned to teams called GrpA, GrpB, GrpC, ... in 
boustrophedonic order.
EOF
  $this->{'names'} = [qw(ats assignteamssnaked)];
  $this->{'argtypes'} = [qw(Round0 NumberOfTeams Division)];
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
  my ($r1, $nt, $dp) = @_;
  my $r0 = $r1 - 1;
  my $config = $tournament->Config();
  my $max_rounds = $config->Value('max_rounds');
  my (@ps) = TSH::Player::SortByStanding($r0, $dp->Players());
  TSH::Player::SpliceInactive(@ps, 0, $r0);
  my (@team_names) = ();
  {
    my $team_name = 'A';
    for my $i (1..$nt) { 
      push(@team_names, $team_name++);
      }
  }
  my $cursor = 0;
  my $direction = 1;
  for my $p (@ps) {
    $p->Team('Grp'.$team_names[$cursor]);
    $cursor += $direction;
    if ($cursor >= $nt) { $cursor = $nt-1; $direction = -1; }
    elsif ($cursor < 0) { $cursor = 0; $direction = 1; }
    }
  $dp->Dirty(1);
  $this->Processor()->Flush();
  $tournament->TellUser('iatsok');
  }

=back

=cut

1;
