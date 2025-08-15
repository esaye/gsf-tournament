#!/usr/bin/perl

# Copyright (C) 2016 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::Command::MoVePlayer;

use strict;
use warnings;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::MoVePlayer - implement the C<tsh> MoVePlayer command

=head1 SYNOPSIS

  my $command = new TSH::Command::MoVePlayer;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::MoVePlayer is a subclass of TSH::Command.

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
Use the MoVePlayer command to move a player from one division to another,
and/or to change their player number.  
If you have generated any reports involving the affected division(s), 
you should subsequently regenerate them.
To move player A2 to the end of division B, enter 'mvp A 2 B'.  
To turn player A2 into player B4 (and if necessary renumber players numbered
4 and up in division B), enter 'mvp A 2 B 4'.  
To keep player A2 in division A but change their player number to 3,
enter 'mvp A 2 3'.
EOF
  $this->{'names'} = [qw(mvp moveplayer)];
  $this->{'argtypes'} = [qw(Division Player OptionalDivision OptionalInteger)];
# print "names=@$namesp argtypes=@$argtypesp\n";

  return $this;
  }

sub MoveDivision ($$$$$) {
  my $this = shift;
  my $dp1 = shift;
  my $pn1 = shift;
  my $dp2 = shift;
  my $pn2 = shift;

  my $pp = $dp1->Player($pn1) or die ['erenumpnop', $dp1->Name(), $pn1];
  $dp1->DeletePlayer($pn1); # can throw error to Processor
  $dp2->AddPlayer(%$pp); # can throw error to Processor
  $dp2->RenumberPlayer($pp->ID(), $pn2); # can throw error to Processor
  }

sub new ($) { return TSH::Utility::new(@_); }

sub Renumber ($$$$) {
  my $this = shift;
  my $dp = shift;
  my $pn1 = shift;
  my $pn2 = shift;

  $dp->RenumberPlayer($pn1, $pn2); # can throw error
  }

=item $command->Run($tournament, @parsed_args)

Should run the command in the context of the given
tournament with the specified parsed arguments.

=cut

sub Run ($$@) { 
  my $this = shift;
  my $tournament = shift;
  my $dp1 = shift;
  my $pn1 = shift;
  my $dp2 = shift;
  my $pn2 = shift;

  my $p = $dp1->Player($pn1);
  ($dp2, $pn2) = (undef, $dp2) if (!ref($dp2)) and !$pn2;
  if ($dp2) {
    if ($dp2->LastPairedRound0() >= 0) {
      $tournament->TellUser('epaired');
      return 0;
      }
    $this->MoveDivision($dp1, $pn1, $dp2, $pn2);
    }
  elsif ($pn2) {
    $this->Renumber($dp1, $pn1, $pn2);
    }
  else {
    $this->Processor->Process('help mvp');
    return 0;
    }

  $this->Processor()->Flush();
  $tournament->TellUser('imvpok', $p->Name(), $p->ID(), $p->Division()->Name());
  return 0;
  }

=back

=cut

=head1 BUGS

None known.

=cut

1;


