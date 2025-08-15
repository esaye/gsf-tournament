#!/usr/bin/perl

# Copyright (C) 2007-2010 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::TOTalOpponentScore;

use strict;
use warnings;

use TSH::Log;
use TSH::Utility;
use TSH::ReportCommand::ExtremePlayers;

our (@ISA) = qw(TSH::ReportCommand::ExtremePlayers);

=pod

=head1 NAME

TSH::Command::TOTalOpponentScore - implement the C<tsh> TOTalOpponentScore command

=head1 SYNOPSIS

  my $command = new TSH::Command::TOTalOpponentScore;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::TOTalOpponentScore is a subclass of TSH::Command::ReportCommand::ExtremePlayers.

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
Use this command to list the players whose total opponent scores are the
highest in a division.
If you specify an integer, it indicates the number of scores you
would like to see.  If not, 20 scores are shown. 
EOF
  $this->{'names'} = [qw(totos totalopponentscore)];
  $this->{'argtypes'} = [qw(OptionalInteger Division)];
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
  my $dp = pop @_;
  my $max_entries = @_ ? shift @_ : 20;

  my $setupp = $this->SetupReport(
    'comparator' => sub ($$) { $_[1][0] <=> $_[0][0] }, # big values first
    'evaluator' => sub ($) {
      my $p = shift;
      my $sum = 0;
      for my $r0 (0..$p->CountScores()-1) {
	$sum += ($p->OpponentScore($r0) || 0);
	}
      return $sum;
      },
    'dp' => $dp,
    'max_entries' => $max_entries,
    'selector' => sub ($) { $_[0]->Active(); },
    'type' => 'totaloppscore',
    );
  my @types;
  push(@types, qw(rank p-opptotal p-wl p-spread));
  if ($setupp->{'has_classes'}) {
    push(@types, 'p-class');
    }
  push(@types, qw(p-name));
  $this->SetupColumns(@types);
  $this->WriteData(@types);
  }

=back

=cut

=head1 BUGS

None known.

=cut


1;

