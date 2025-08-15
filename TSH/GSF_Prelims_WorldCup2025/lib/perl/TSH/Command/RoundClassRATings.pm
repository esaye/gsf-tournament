#!/usr/bin/perl

# Copyright (C) 2012 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::RoundClassRATings;

use strict;
use warnings;

use TSH::Log;
use TSH::Utility qw(Debug DebugOn);
use TSH::Command::RoundRATings;

# DebugOn('SP');

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::RoundClassRATings - implement the C<tsh> RoundClassRATings command

=head1 SYNOPSIS

  my $command = new TSH::Command::RoundClassRATings;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::RoundClassRATings is a subclass of TSH::Command.

=cut

=head1 DESCRIPTION

=over 4

=cut

sub initialise ($@);
sub new ($);
sub Run ($$@);

=item $parserp->initialise()

Used internally to (re)initialise the object.

=cut

sub initialise ($@) {
  my $this = shift;

  $this->SUPER::initialise(@_);
  $this->{'help'} = <<'EOF';
This command works like the RoundRATings command (q.v.), but groups
players within classes.  If you specify just one round, the results
will be displayed on the screen.  If you specify a range of rounds
(e.g., 4-7), the results will not be shown on your screen but report
files will be updated.
EOF
  $this->{'names'} = [qw(rcrat roundclassratings)];
  $this->{'argtypes'} = [qw(RoundRange Division)];

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
  my $firstr0 = $firstr1 - 1;
  my $lastr0 = $lastr1 - 1;
  my $config = $tournament->Config();
  my $optionsp = TSH::Command::RoundRATings::SetupOptions($config, $dp, $this->{'noconsole'});
  $optionsp->{'byclass'} = 1;
  $optionsp->{'filename'} = 'class-ratings';
  $optionsp->{'titlename'} = 'Class_Ratings';
  $optionsp->{'refresh'} = $config->Value('standings_refresh');

  TSH::Command::RoundRATings::RenderAll($dp, $firstr1, $lastr1, $optionsp);

  return 0;
  }

=back

=cut

1;


