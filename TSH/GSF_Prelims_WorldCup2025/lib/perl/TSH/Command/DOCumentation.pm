#!/usr/bin/perl

# Copyright (C) 2006 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::DOCumentation;

use strict;
use warnings;

use TSH::Utility;
use File::Spec;
use Cwd qw(abs_path);

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::DOCumentation - implement the C<tsh> DOCumentation command

=head1 SYNOPSIS

  my $command = new TSH::Command::DOCumentation;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::DOCumentation is a subclass of TSH::Command.

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
Use this command to launch your web browser to view the tsh reference
documentation.  For documentation specific to a plug-in, name the 
plug-in, e.g. "doc plus", "doc thai".
EOF
  $this->{'names'} = [qw(doc documentation)];
  $this->{'argtypes'} = [qw(OptionalPlugIn)];
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
  my $plug_in = shift;
  my $config = $tournament->Config();
  my $url = $config->MakeLibPath('../doc/all.html', $plug_in);
  if (!File::Spec->file_name_is_absolute($url)) {
    $url = abs_path($url);
    }
  $url = "file://$url";
  TSH::Utility::Browse($url);
  0;
  }

=back

=cut

1;
