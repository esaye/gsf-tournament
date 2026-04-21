#!/usr/bin/perl

# Copyright (C) 2005 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::PairMany;

use strict;
use warnings;

use TSH::Utility;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::PairMany - implement the C<tsh> PairMany command

=head1 SYNOPSIS

  my $command = new TSH::Command::PairMany;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::PairMany is a subclass of TSH::Command.

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
Use the PairMany command to manually add pairings a large number
of pairings where the order of play is determined independently of 
the order of entry.  To add a bye, give one player number as 0.
To change divisions, enter a division name by itself.
To change rounds, enter the letter "R", a space, then a round number.
EOF
  $this->{'names'} = [qw(pm pairmany)];
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

  my $dname = $dp->Name();
  my $config = $tournament->Config();
  my $track_firsts = $config->Value('track_firsts');
# warn $track_firsts;
  while (1) {
    TSH::Utility::Prompt "[$dname$round]:pn1 pn2?";
#   local($_) = $config->DecodeConsoleInput(scalar(<STDIN>));
    local($_) = scalar(<STDIN>);
    s/\s+$//;
    if (my $newdp = $tournament->GetDivisionByName($_)) {
      $dp = $newdp;
      next;
      }
    elsif (/^\s*r\s*(\d+)\s*$/i) {
      $round = $1;
      next;
      }
    next unless $tournament->ExpandNames($_, $dp);
    my (@pns) = split;
    last if /[^-\d\s]/;
    last if @pns != 2;
    my (@pps) = map { $dp->Player($_) } grep { $_ } @pns;
    my $has_scores = 0;
    foreach my $pp (@pps) {
        if ($pp->Score($round-1)) {
          $tournament->TellUser('ehasspm', $pp->TaggedName(), $pp->Score($round-1));
          $has_scores = 1;
        }
      }
    next if ($has_scores);
    $dp->Pair($pns[0], $pns[1], $round-1, 'repair');
    for my $i (0..1) {
      my $p = $pps[$i];
      if ($p) {
	printf "%s (%.1f %+d)",
	  $p->TaggedName(), $p->Wins(), $p->Spread();
	}
      else { print 'bye'; }
      print $i ? ".\n" : ' - ';
      }
    }
  $this->Processor()->Flush();
  }

=back

=cut

=head1 BUGS

Should use a subprocessor rather than an event loop.

=cut

1;
