#!/usr/bin/perl

# Copyright (C) 2014 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::Command::MIRROR;

use strict;
use warnings;

use TSH::Utility;
use File::Spec;

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::MIRROR - implement the C<tsh> MIRROR command

=head1 SYNOPSIS

  my $command = new TSH::Command::MIRROR;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::MIRROR is a subclass of TSH::Command.

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
Use this command to open a new window running an application
that will mirror your web files to an FTP server.
EOF
  $this->{'names'} = [qw(mirror)];
  $this->{'argtypes'} = [qw()];
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
  my $config = $tournament->Config();
  my $ftp_host = $config->Value('ftp_host');
  my $ftp_path = $config->Value('ftp_path');
  unless ((defined $ftp_host) && defined $ftp_path) {
    $tournament->TellUser('eneedftp');
    return 0;
    }
  TSH::Utility::ExecInNewWindow('util/mirror-ftp', $config->RootDirectory());
  # Windows needs: system "start perl util\\mirror-ftp"
  0;
  }

=back

=cut

1;

