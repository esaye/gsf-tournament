#!/usr/bin/perl

# Copyright (C) 2009 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::saveJSON;

use strict;
use warnings;

use TSH::Utility;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::saveJSON - implement the C<tsh> saveJSON command

=head1 SYNOPSIS

  my $command = new TSH::Command::saveJSON;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::saveJSON is a subclass of TSH::Command.

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
Use this command to create a JSON .js file, 
for exporting the tournament's current data to
a JavaScript application.
EOF
  $this->{'names'} = [qw(savejson json)];
  $this->{'argtypes'} = [qw()];
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
  if ($tournament->SaveJSON()) {
    $tournament->TellUser('idone');
    }
  else {
    $tournament->TellUser('esavejson', $!);
    }
  }

=back

=cut

=head1 BUGS

None known

=cut

1;
