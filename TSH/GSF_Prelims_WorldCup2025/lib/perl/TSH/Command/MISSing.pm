#!/usr/bin/perl

# Copyright (C) 2005 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::MISSing;

use strict;
use warnings;

use TSH::Utility qw(PrintConsoleCrossPlatform);

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::MISSing - implement the C<tsh> MISSing command

=head1 SYNOPSIS

  my $command = new TSH::Command::MISSing;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::MISSing is a subclass of TSH::Command.

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
Use this command to see which player scores have yet to be entered
in a given division.
EOF
  $this->{'names'} = [qw(miss missing)];
  $this->{'argtypes'} = [qw(Round OptionalDivision)];
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
  my ($round, $dp1) = @_;
  my $config = $tournament->Config();
  my $round0 = $round-1;
  my $noboards = $config->Value('no_boards');
  my $found = 0;
  my (@dp) = (defined $dp1) 
    ? ($dp1)
    : (sort { $a->Name() cmp $b->Name() } $tournament->Divisions());
  for my $dp (@dp) {
    my $c_has_tables = $dp->HasTables();
    my @done = ();
    for my $p (TSH::Player::SortByCurrentStanding $dp->Players()) {
      next unless $p->Active();
      my $id = $p->ID();
      next if $done[$id];
      next if defined $p->Score($round0);

      my $opp = $p->Opponent($round0);
      my $partial = '';
      # TODO: should use Player::RoundProvisionalScore
      my $provsp = $p->GetOrSetEtcVector('rprov');
      if ($provsp and @$provsp and $provsp->[-3] >= $round) {
	$partial = " UNCONFIRMED";
	}
      elsif ($opp) {
        $provsp = $opp->GetOrSetEtcVector('rprov');
        if ($provsp and @$provsp and $provsp->[-3] >= $round) {
	  $partial = " UNCONFIRMED";
	  }
        }
      $found++;
      if (my $board = $p->Board($round0)) { 
	if ($c_has_tables) {
	  printf "Table $config::table_format. ", $dp->BoardTable($board);
	  }
	elsif (!$noboards) {
	  printf "Board $config::table_format. ", $board;
	  }
	}
      if ($opp) {
	PrintConsoleCrossPlatform $dp->FormatPairing($round0, $id);
	$done[$opp->ID()] = 1;
	}
      else {
	PrintConsoleCrossPlatform $p->TaggedName();
	}
      PrintConsoleCrossPlatform "$partial\n";
      }
    }
  unless ($found) {
    $tournament->TellUser('imissingnot');
    }
  0;
  }
 
=back

=cut

=head1 BUGS

=cut

1;
