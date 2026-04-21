#!/usr/bin/perl

# Copyright (C) 2006 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::Command::BrowseLast;

use strict;
use warnings;

use TSH::Utility;
use File::Spec;
use Cwd qw(abs_path);

our (@ISA) = qw(TSH::Command);

=pod

=head1 NAME

TSH::Command::BrowseLast - implement the C<tsh> BrowseLast command

=head1 SYNOPSIS

  my $command = new TSH::Command::BrowseLast;
  my $argsp = $command->ArgumentTypes();
  my $helptext = $command->Help();
  my (@names) = $command->Names();
  $command->Run($tournament, @parsed_arguments);
  
=head1 ABSTRACT

TSH::Command::BrowseLast is a subclass of TSH::Command.

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
Use this command to launch your web browser to view the last report
that you requested.
EOF
  $this->{'names'} = [qw(bl browselast)];
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
  my $html_suffix = $config->Value('html_suffix');
  my $url = $config->MakeHTMLPath($tournament->LastReport()||"index$html_suffix");
  unless (-e $url) {
    $tournament->TellUser('enohtml');
    return 0;
    }
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
