#!/usr/bin/perl

# Copyright (C) 2008-2011 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::UPDATERATINGS;

use strict;
use warnings;

use TSH::UpdateCommand;
use WebUpdate;

our (@ISA) = qw(TSH::UpdateCommand);

=pod

=head1 NAME

TSH::Command::UPDATERATINGS - implement the C<tsh> UPDATERATINGS command

=head1 SYNOPSIS

  my $command = new TSH::Command::UPDATERATINGS;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::UPDATERATINGS is a subclass of TSH::Command.

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
Use this command to update your ratings databases over an
Internet connection.
EOF
  $this->{'names'} = [qw(updateratings)];
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
  my $config = $this->Processor()->Tournament()->Config();
  $this->CheckOne($config->MakeLibPath('ratings/nsa/MANIRATS.txt'), 'rating database');
  }

=item $command->Run($tournament, @parsed_args)
=item $command->Run($tournament, @parsed_args)

Should run the command in the context of the given
tournament with the specified parsed arguments.

=cut

sub Run ($$@) {
  my $this = shift;
  my $tournament = shift;
  my $config = $tournament->Config();

  my (@dbs) = (
#   ['ratings/absp', 'www.poslfit.com', '/ratings/absp'],
    ['ratings/wespa', 'www.poslarchive.com', '/ratings/wespa'],
    ['ratings/pak', 'www.poslarchive.com', '/ratings/pak'],
    ['ratings/ken', 'www.poslarchive.com', '/ratings/ken'],
    ['ratings/nsa', 'www.scrabbleplayers.org', '/ratings/data/full'],
    ['ratings/naspa-csw', 'www.scrabbleplayers.org', '/ratings/data/csw/full'],
    ['ratings/nor', 'scrabbeller.scrabbleforbundet.no', '/tsh'],
    );
  
  for my $dbp (@dbs) {
    my ($localpath, $server, $remotepath) = @$dbp;
    my $locallibpath = $config->MakeLibPath($localpath);
    mkdir $locallibpath; # just in case
    my $wup = new WebUpdate(
      'server' => $server,
      'basepath' => $remotepath,
      'manifest' => 'MANIRATS.txt',
      'localpath' => $locallibpath,
      );
    $tournament->TellUser('iconnrat', $server, "$localpath/current.txt");
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

  # ABSP maintains own 
  }

=back

=cut

1;
