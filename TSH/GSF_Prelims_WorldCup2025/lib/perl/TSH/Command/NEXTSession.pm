#!/usr/bin/perl

# Copyright (C) 2017 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::Command::NEXTSession;

use strict;
use warnings;

# use TSH::ParseArgs::Session;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::NEXTSession - implement the C<tsh> NEXTSession command

=head1 SYNOPSIS

  my $command = new TSH::Command::NEXTSession;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::NEXTSession is a subclass of TSH::Command.

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
Use this command to create the next session following the current
series session.
EOF
  $this->{'names'} = [qw(nexts nextsession)];
  $this->{'argtypes'} = [qw(Session)];
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
  my $optionsp = $this->Setup($tournament, @_) or return;
  my $config = $optionsp->{'config'};
  my $series = $optionsp->{'series'};

  # Rebuild the output ratings file for this session to include the next link
  $series->NextSessionID($optionsp->{'next_session_id'});
  $this->Processor()->Process('EXPORTRATINGS');

  # make a virtual new session tournament
  my $t2 = new TSH::Tournament({'virtual' => 1, 'silent' => 1});
  my $newconfig = $t2->Config();
  # not the following line, which tries to run Setup()
  # $t2->LoadConfiguration($config->Render('raw' => 1));
  # but the following line instead
  $newconfig->Read($config->Render('raw'=>1));
  $newconfig->Series()->PreviousSessionID($series->SessionID());
  $t2->CopyDivisions($tournament);

  # modify it appropriately
  for my $dp ($t2->Divisions()) { 
    $dp->DeactivateAllPlayers(0); 
    $dp->Truncate(-1);
    for my $p ($dp->Players()) {
      $p->InitialRecord([]);
      }
    }

  # save it to disk
  $newconfig->RootDirectory($optionsp->{'next_session_path'});
  $newconfig->Value('filename', 'config.tsh');
  $newconfig->ReadOnly(0);
  $newconfig->Setup(); # create old/ etc.
  $newconfig->Save('mode'=>'update');
  for my $dp ($t2->Divisions()) {
    $dp->Write();
    }
  die "need to export ratings";

  return;
  }

=item $optionsp = $command->Setup($tournament, @parsed_args)

Check to make sure that the command has been called appropriately and
return a hash of set up data if so; otherwise return undef.

=cut

sub Setup ($$@) {
  my $this = shift;
  my $tournament = shift;
  my (%options) = (
    'next_session_id' => $_[0],
    'tournament' => $tournament,
    );

  my $config = $options{'config'} = $tournament->Config();
  if ($config->ReadOnly()) {
    $tournament->TellUser('ecfgro');
    return undef;
    }

  my $series = $options{'series'} = $config->Series();
  unless (defined $series) {
    $tournament->TellUser('ecfgreq', 'series_id');
    return undef;
    }

  {
    my $old_next_session_id = $series->NextSessionID();
    if ($old_next_session_id
      and $old_next_session_id ne $options{'next_session_id'}) {
      $tournament->TellUser('eisnsi');
      return undef;
      }
  }

  $options{'next_session_path'} =
    $config->MakeSessionSiblingPath($options{'next_session_id'});
  unless (-e $options{'next_session_path'}) {
    mkdir $options{'next_session_path'} or do {
      $tournament->TellUser('edircre', $options{'next_session_path'}, $!);
      return undef;
      };
    }

  $options{'next_session_config_path'} =
    $config->MakeSessionSiblingPath($options{'next_session_id'}, 'config.tsh');
  if (-e $options{'next_session_config_path'}) {
    $tournament->TellUser('ecfgexs', $options{'next_session_path'});
    return undef;
    }

  return \%options;
  }

=back

=cut

1;

