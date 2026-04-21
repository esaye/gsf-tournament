#!/usr/bin/perl

# Copyright (C) 2005 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::RESETEVERYTHING;

use strict;
use warnings;

use TSH::Log;
use TSH::Utility qw(Debug DebugOn);

# DebugOn('SP');

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::RESETEVERYTHING - implement the C<tsh> RESETEVERYTHING command

=head1 SYNOPSIS

  my $command = new TSH::Command::RESETEVERYTHING;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::RESETEVERYTHING is a subclass of TSH::Command.

=cut

=head1 DESCRIPTION

=over 4

=cut

sub initialise ($$$$);
sub new ($);
sub Run ($$@);
sub ShowAlphaPairings ($$$);
sub ShowBye ($$$);
sub ShowHeader ($$$);
sub ShowUnpaired ($$$);

=item $parserp->initialise()

Used internally to (re)initialise the object.

=cut

sub initialise ($$$$) {
  my $this = shift;

  $this->{'help'} = <<'EOF';
Use this command with caution to reset all data for the event, as
though the event had not yet taken place.
EOF
  $this->{'names'} = [qw(reseteverything)];
  $this->{'argtypes'} = [qw()];

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
  my $config = $tournament->Config();
  my $processor = $this->Processor();
  my $html_suffix = $config->Value('html_suffix');

  for my $dp ($tournament->Divisions()) {
    my $dname = $dp->Name();
    $processor->Process("truncaterounds 0 $dname");
    unlink($config->MakeRootPath('prizes.doc'));
    unlink(glob($config->MakeRootPath("$dname-*.doc")));
    unlink(glob($config->MakeRootPath("$dname-*$html_suffix")));
    unlink(glob($config->MakeHTMLPath("$dname-*$html_suffix")));
    }
  unlink(glob($config->MakeBackupPath('*')));
  unlink(glob($config->MakeHTMLPath("*$html_suffix")));
  }

=back

=cut

=head1 BUGS

None known.

=cut

1;
