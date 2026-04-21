#!/usr/bin/perl

# Copyright (C) 2008 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::UPDATE;

use strict;
use warnings;

use TSH::UpdateCommand;
use WebUpdate;

our (@ISA) = qw(TSH::UpdateCommand);

=pod

=head1 NAME

TSH::Command::UPDATE - implement the C<tsh> UPDATE command

=head1 SYNOPSIS

  my $command = new TSH::Command::UPDATE;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::UPDATE is a subclass of TSH::Command.

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
Use this command to update your copy of tsh from
the tsh web site.
EOF
  $this->{'names'} = [qw(update)];
  $this->{'argtypes'} = [qw()];
# print "names=@$namesp argtypes=@$argtypesp\n";

  return $this;
  }

sub new ($) { return TSH::Utility::new(@_); }

=item $command->Check()

Check to see if updates are advisable.

=cut

sub Check ($) {
  my $this = shift;
  $this->CheckOne('MANIFEST.txt', 'TSH software');
  }

=item $command->Run($tournament, @parsed_args)

Should run the command in the context of the given
tournament with the specified parsed arguments.

=cut

sub Run ($$@) {
  my $this = shift;
  my $tournament = shift;

  my $wup = new WebUpdate(
    'server' => 'tsh.poslfit.com',
    'basepath' => '',
    'localpath' => '',
    'manifest' => 'MANIFEST.txt',
    );
  $tournament->TellUser('iconnupd', 'tsh.poslfit.com', 'TSH');
  my $status = $wup->Update();
  if ($status > 0) {
    $tournament->TellUser('iupdok');
    }
  elsif ($status == 0) {
    $tournament->TellUser('iupdnone');
    }
  else {
    $tournament->TellUser('iupdabort');
    }
  }

=back

=cut

1;
