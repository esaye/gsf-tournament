#!/usr/bin/perl

# Copyright (C) 2012 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::ParseArgs::OptionalKey;

use strict;
use warnings;

use TSH::Utility;

=pod

=head1 NAME

TSH::ParseArgs::OptionalKey - match an optional alphanumeric key

=head1 SYNOPSIS

  my $parser = new TSH::ParseArgs::OptionalKey;

=head1 ABSTRACT

This Perl module is used by C<ParseArgs.pm> to ignore command-line arguments.

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

=item $parserp = new ParserArgs::OptionalKey

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
  my (@words);
  my $value = $line_parser->GetArg();
  if (!defined $value) {
    return ();
    }
  if ($value =~ /\W/) {
    $line_parser->Error("Keys must contain only alphanumeric characters.");
    }
  return $value;
  }

=item $argument_description = $this->Usage()

Briefly describe this argument's usage (in a word or hyphenated phrase)

=cut

sub Usage ($) {
  my $this = shift;
  return '[key]';
  }

=back

=head1 BUGS

None known.

=cut

1;
