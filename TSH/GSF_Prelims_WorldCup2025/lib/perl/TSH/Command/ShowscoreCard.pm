#!/usr/bin/perl

# Copyright (C) 2005-2010 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::ShowscoreCard;

use strict;
use warnings;

use TSH::Log;
use TSH::Utility;
use TSH::Report::CSC;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::ShowscoreCard - implement the C<tsh> ShowscoreCard command

=head1 SYNOPSIS

  my $command = new TSH::Command::ShowscoreCard;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::ShowscoreCard is a subclass of TSH::Command.

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
Use this command to display an electronic version of a player's
scorecard, either to find discrepancies or to reprint a lost
card.
Specify the division name and player number of the scorecard
that you wish to view.
EOF
  $this->{'names'} = [qw(sc showscorecard)];
  $this->{'argtypes'} = [qw(Division Player)];
# print "names=@$namesp argtypes=@$argtypesp\n";

  return $this;
  }

sub new ($) { return TSH::Utility::new(@_); }

=item $command->Run($tournament, @parsed_args)

Should run the command in the context of the given
tournament with the specified parsed arguments.

=cut

# TODO: split this up into smaller subs for maintainability

sub Run ($$@) { 
  my $this = shift;
  my $tournament = shift;
  my ($dp, $pn) = @_;
  my $p = $dp->Player($pn);
  unless (defined $p) { $tournament->TellUser('ebadp', $pn); return; }
  my $csc = new TSH::Report::CSC($p);
  my $logp = new TSH::Log($tournament, $dp, 'scorecard', "p$pn", { 
    'notitle' => 1,
    });
  my ($text, $html) = $csc->GetBoth();
  $logp->Write($text, $html);
  $logp->Close();
  }

=back

=cut

1;
