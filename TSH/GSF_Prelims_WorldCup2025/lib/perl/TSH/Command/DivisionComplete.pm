#!/usr/bin/perl

# Copyright (C) 2010 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::DivisionComplete;

use strict;
use warnings;

use TSH::Log;
use TSH::Utility qw(Debug DebugOn);

# DebugOn('SP');

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::DivisionComplete - implement the C<tsh> DivisionComplete command

=head1 SYNOPSIS

  my $command = new TSH::Command::DivisionComplete;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::DivisionComplete is a subclass of TSH::Command.

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
Use this command to manually trigger the hook_division_complete hook.
EOF
  $this->{'names'} = [qw(dc divisioncomplete)];
  $this->{'argtypes'} = [qw(RoundRange Divisions)];
# print "names=@$namesp argtypes=@$argtypesp\n";

  return $this;
  }

sub new ($) { return TSH::Utility::new(@_); }

=item RenderTable($dp, $r0, $termsp)

Render the rows of the ratings table. This code is independent of
rating system.

=cut


=item $command->Run($tournament, @parsed_args)

Should run the command in the context of the given
tournament with the specified parsed arguments.

=cut

sub Run ($$@) { 
  my $this = shift;
  my $tournament = shift;
  my $config = $tournament->Config();
  my ($firstr1, $lastr1, @dps) = @_;

  for my $dp (@dps) {
    my $dname = $dp->Name();
    if (my $cmds = $config->Value('hook_division_complete')->{$dname}) {
      for my $r1 ($firstr1..$lastr1) {
	$this->Processor()->RunHook('hook_division_complete', $cmds, 
	  { 'nohistory' => 1,
	    'noconsole' => $config->Value('quiet_hooks') },
	  { 'r' => $r1,
	    'd' => $dname},
	  );
	}
      }
    }

  return 0;
  }

=back

=cut

1;

