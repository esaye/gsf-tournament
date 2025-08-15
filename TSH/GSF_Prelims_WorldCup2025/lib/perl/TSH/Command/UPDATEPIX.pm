#!/usr/bin/perl

# Copyright (C) 2008 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::UPDATEPIX;

use strict;
use warnings;

use TSH::UpdateCommand;
use WebUpdate;

our (@ISA) = qw(TSH::UpdateCommand);

=pod

=head1 NAME

TSH::Command::UPDATEPIX - implement the C<tsh> UPDATEPIX command

=head1 SYNOPSIS

  my $command = new TSH::Command::UPDATEPIX;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::UPDATEPIX is a subclass of TSH::Command.

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
Use this command to update your optional player photo database
over an Internet connection.
EOF
  $this->{'names'} = [qw(updatepix)];
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
  my $tournament = $this->Processor->Tournament();
  my $config = $tournament->Config();
  my ($photo_database, $dbsp) = $this->GetDatabases($tournament);
  for my $dbp (@$dbsp) {
    my ($localpath, $server, $remotepath) = @$dbp;
    my $pixpath = $config->MakeLibPath($localpath);
    $this->CheckOne(
      File::Spec->join($pixpath, "MANIPICS.txt"),
      "$photo_database photo database"
    );
    }
  }

=item $command->Run($tournament, @parsed_args)

Should run the command in the context of the given
tournament with the specified parsed arguments.

=cut

my (%gDatabases) = (
  'centrestar' => [['pix/centrestar', 'www.centrestar.co.uk', '/pdb']],
  'deu' => [['pix/deu', 'www.poslfit.com', '/deu/pdb']],
# 'nsa' => [['pix', 'www.scrabble-assoc.com', '/players']],
  'nga' => [['pix/nga', 'www.poslarchive.com', '/nga/pdb']],
  'nsa' => [['pix', 'www.scrabbleplayers.org', '/players']],
  'pak' => [['pix/pak', 'pak.poslfit.com', '/pdb']],
  'ken' => [['pix/ken', 'www.poslarchive.com', '/kenya/pdb']],
  );

sub GetDatabases ($$) {
  my $this = shift;
  my $tournament = shift;
  my $config = $tournament->Config();
  my $photo_database = $config->Value('photo_database') || 'nsa';
  my $dbsp = $gDatabases{$photo_database} || $gDatabases{'nsa'};
  
  return ($photo_database, $dbsp);
  }

sub Run ($$@) {
  my $this = shift;
  my $tournament = shift;
  my $config = $tournament->Config();
  my ($photo_database, $dbsp) = $this->GetDatabases($tournament);

  for my $dbp (@$dbsp) {
    my ($localpath, $server, $remotepath) = @$dbp;
    my $pixpath = $config->MakeLibPath($localpath);
    mkdir $pixpath; # just in case
    my $wup = new WebUpdate(
      'server' => $server,
      'basepath' => $remotepath,
      'manifest' => 'MANIPICS.txt',
      'localpath' => $pixpath,
      );
    $tournament->TellUser('iconnupd', $server, "$photo_database photos");
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
  }

=back

=cut

1;
