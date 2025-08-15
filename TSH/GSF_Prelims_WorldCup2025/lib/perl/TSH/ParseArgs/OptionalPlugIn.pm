#!/usr/bin/perl

# Copyright (C) 2012 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::ParseArgs::OptionalPlugIn;

use strict;
use warnings;

use TSH::Utility;

=pod

=head1 NAME

TSH::ParseArgs::PlugIn - handle a command-line argument that should be a plug-in name but may be omitted

=head1 SYNOPSIS

  my $parser = new TSH::ParseArgs::OptionalPlugIn;

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
  my $value = $line_parser->GetArg();
  return () unless defined $value;
  unless ($::gPlugInManager->GetPlugInInfo({'id' => $value})) {
    $line_parser->UnGetArg($value);
    return ();
    }
  return lc $value if $value =~ /^\w+$/;
  return ();
  }

=item $argument_description = $this->Usage()

Briefly describe this argument's usage (in a word or hyphenated phrase)

=cut

sub Usage ($) {
  my $this = shift;
  return '[plug-in]';
  }

=back

=cut

1;
