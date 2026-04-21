#!/usr/bin/perl

# Copyright (C) 2011 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::TopPlayersOnly;

use strict;
use warnings;

use TSH::Command;
use TSH::Utility;

our (@ISA) = qw(TSH::Command);
our @Pairings;
our @Starts;

=pod

=head1 NAME

TSH::Command::TopPlayersOnly - implement the C<tsh> TopPlayersOnly command

=head1 SYNOPSIS

  my $command = new TSH::Command::TopPlayersOnly;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::TopPlayersOnly is a subclass of TSH::PairingCommand.

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
Use the TopPlayersOnly command to remove from subsequent pairings
all players who are not among the top however many active players.
assigning the remainder scoreless byes until reactivated.
Specify the number of active players to keep, the round on whose
rankings the players should be selected, and the division if necessary.
EOF
  $this->{'names'} = [qw(tpo topplayersonly)];
  $this->{'argtypes'} = [qw(Rank Round Division)];
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
  my ($last_rank, $sr, $dp) = @_;
  my $config = $tournament->Config();
  # do not use HasSpreadCaps, which also checks standing_spread_cap
  my $is_capped = $config->Value('spread_cap');
  my $sr0 = $sr - 1;
  
  my (@ps) = grep { $_->Active() } $dp->Players();
  if ($is_capped) {
    $dp->ComputeCappedRanks($sr0);
    @ps = TSH::Player::SortByCappedStanding($sr0, @ps);
    }
  else {
    $dp->ComputeRanks($sr0);
    @ps = TSH::Player::SortByStanding($sr0, @ps);
    }

  if ($last_rank <= $#ps) {
    for my $i ($last_rank..$#ps) {
      $ps[$i]->GetOrSetEtcScalar('off', 0);
      }
    }

  $this->Processor->Flush();
  $tournament->TellUser('idone');
  }

=cut

=head1 BUGS

None known.

=cut

1;
