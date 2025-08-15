#!/usr/bin/perl

# Copyright (C) 2007-2010 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::HighRoundWins;

use strict;
use warnings;

use TSH::Division::FindExtremeGames;
use TSH::Log;
use TSH::Utility;
use TSH::ReportCommand::ExtremeGames;

our (@ISA) = qw(TSH::ReportCommand::ExtremeGames);

=pod

=head1 NAME

TSH::Command::HighRoundWins - implement the C<tsh> HighRoundWins command

=head1 SYNOPSIS

  my $command = new TSH::Command::HighRoundWins;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::HighRoundWins is a subclass of TSH::Command.

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
Use this command to list the high winning scores in a division
in one or more rounds.
EOF
  $this->{'names'} = [qw(hrw highroundwins)];
  $this->{'argtypes'} = [qw(RoundRange Division)];
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
  my ($firstr1, $lastr1, $dp) = @_;
  return if $firstr1 > $lastr1;
  my $max_entries = 1;

  my $comparator = sub ($$) { $_[1][0] <=> $_[0][0] }; # big wins first
  my $setupp = $this->SetupReport(
    'comparator' => $comparator,
    'dp' => $dp,
    'max_entries' => $max_entries,
    'selector' => undef,
    'type' => 'highwin',
    );

  my (@types);
  push(@types, qw(round p1-winning-score p2-losing-score));
  if ($setupp->{'has_classes'}) {
    push(@types, 'p1-class');
    }
  push(@types, qw(p1-winner p2-loser));
  $this->SetupColumns(@types);

  for my $r1 ($firstr1..$lastr1) {
    my $r0 = $r1 - 1;
    #  games are represented as lists: [$score1, $score2, $p1, $p2, $r0, $rat1, $rat2].
    my $entriesp = TSH::Division::FindExtremeGames::Search($dp, $max_entries+10, 
      sub ($) { 
	my $e = $_[0];
	$e->[4] == $r0 # round0 == $r0
	  && (defined $e->[0]) 
	  && (defined $e->[1]) 
	  && $e->[0] > $e->[1] # wins only
	},
      \&$comparator,
      );
    TSH::Utility::DoOneRank( $entriesp, $comparator, 
      sub { my $e = shift; $this->AddRows([$e]); },
      0,
      );
    }
  $this->WriteData(@types);
  }

=back

=cut

=head1 BUGS

None known.

=cut


1;
