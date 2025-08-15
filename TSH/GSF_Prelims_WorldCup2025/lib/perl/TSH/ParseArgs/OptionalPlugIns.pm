#!/usr/bin/perl

# Copyright (C) 2012 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::ParseArgs::OptionalPlugIns;

use strict;
use warnings;

use TSH::Utility;

=pod

=head1 NAME

TSH::ParseArgs::PlugIns - handle a command-line argument that should be zero or more plug-in names.

=head1 SYNOPSIS

  my $parser = new TSH::ParseArgs::OptionalPlugIns;

=head1 ABSTRACT

This Perl module is used by C<ParseArgs.pm> to parse command-line arguments.

=cut

=head1 DESCRIPTION

=over 4

=cut

sub initialise ($);
sub new ($);
sub Parse ($$);
sub Usage ($);

=item $parserp->initialise();

Used internally to (re)initialise the object.

=cut

sub initialise ($) {
  my $this = shift;
  return $this;
  }

=item $parserp = new ParserArgs::Topic;

Create a new instance

=cut

sub new ($) { TSH::Utility::new(@_); }

=item $argument_description = $this->Parse($line_parser)

Return the checked value of the command-line argument,
or () if the argument is invalid.

=cut

sub Parse ($$) {
  my $this = shift;
  my $line_parser = shift;
  my (@plugins);
  my $value;
  while (1) {
    my $value = $line_parser->GetArg();
    last unless defined $value;
    if ($::gPlugInManager->GetPlugInInfo({'id' => $value})) {
      push(@plugins, $value);
      }
    else {
      $line_parser->UnGetArg($value);
      last;
      }
    }
  return @plugins;
  }

=item $argument_description = $this->Usage()

Briefly describe this argument's usage (in a word or hyphenated phrase)

=cut

sub Usage ($) {
  my $this = shift;
  return '[plug-ins]';
  }

=back

=cut

1;
