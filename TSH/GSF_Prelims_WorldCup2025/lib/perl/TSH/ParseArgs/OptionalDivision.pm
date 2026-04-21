#!/usr/bin/perl

# Copyright (C) 2015 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::ParseArgs::OptionalDivision;

use strict;
use warnings;

use TSH::Utility;

=pod

=head1 NAME

TSH::ParseArgs::OptionalDivision - handle a command-line argument that should be a division name if present, but may be omitted

=head1 SYNOPSIS

  my $parser = new TSH::ParseArgs::OptionalDivision;

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
  $this->{'processor'} = shift;
  return $this;
  }

=item $parserp = new ParserArgs::OptionalDivision;

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
  if (!defined $value) {
    return ();
    }
  my $tournament = $this->{'processor'}->Tournament();
  if (defined $value) {
    my $dp = $tournament->GetDivisionByName($value);
    if (defined $dp) {
      $value = $dp;
      }
    else {
#     warn "Not a division: (@{$line_parser->{'argv'}}) $value";
      $line_parser->UnGetArg($value);
      return ();
      }
    }
  return $value;
  }

=item $argument_description = $this->Usage()

Briefly describe this argument's usage (in a word or hyphenated phrase)

=cut

sub Usage ($) {
  my $this = shift;
  return '[division]';
  }

=back

=cut

1;
