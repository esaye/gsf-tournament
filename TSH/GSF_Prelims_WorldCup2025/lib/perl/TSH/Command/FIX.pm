#!/usr/bin/perl

# Copyright (C) 2006 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::FIX;

use strict;
use warnings;

use TSH::Utility;
use File::Spec;
use Cwd qw(abs_path);

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::FIX - implement the C<tsh> FIX command

=head1 SYNOPSIS

  my $command = new TSH::Command::FIX;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::FIX is a subclass of TSH::Command.

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
Use this command to launch your web browser to fix data entry problems.
EOF
  $this->{'names'} = [qw(fix)];
  $this->{'argtypes'} = [qw(Division Player)];
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
  my $dp = shift;
  my $pid = shift;
  my $config = $tournament->Config();
  my $port = $config->Value('gui_port') || 7779;
  my $gui_tourney = new TSH::Tournament({'virtual' => 1});
  $gui_tourney->LoadConfiguration();
  my $gui_processor = new TSH::Processor($gui_tourney);
  my $gui_config = $gui_tourney->Config();
  $gui_config->Value('port', $port);
  $gui_config->RootDirectory('lib/gui');
  $gui_config->DivisionsLoaded();
  my $path = $config->RootDirectory();
  my $url = "http://localhost:$port/events/old/$path/?a=player&d=" . $dp->Name() . '&p=' . $pid;
  print "This command will open up a browser window.\n";
  print "To return to the command-line, click on the button that says:.\n";
  print "'Return to tsh command line'.\n";
  $tournament->SaveJSON();
  $gui_processor->RunServer({'start_hook' => sub ($) {
    my $argh = shift;
    $argh->{'server'}->UserTournament($path, $tournament);
    TSH::Utility::Browse($url) 
    }});
  0;
  }

=back

=cut

1;
