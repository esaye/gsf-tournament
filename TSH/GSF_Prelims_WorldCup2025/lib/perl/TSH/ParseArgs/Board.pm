#!/usr/bin/perl

# Copyright (C) 2011 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::ParseArgs::Board;

use strict;
use warnings;

use TSH::ParseArgs::Integer;
use TSH::Utility;

=pod

=head1 NAME

TSH::ParseArgs::Board - handle a command-line argument that should be a board number

=head1 SYNOPSIS

  my $parser = new TSH::ParseArgs::Board;

=head1 ABSTRACT

This Perl module is used by C<ParseArgs.pm> to ignore command-line arguments.

=cut

=head1 DESCRIPTION

=over 4

=cut

our(@ISA) = qw(TSH::ParseArgs::Integer);

sub CheckMatch ($$);
sub initialise ($$);
sub new ($$);
sub Parse ($$);
sub Usage ($);

=item $parserp->initialise($processor);

Used internally to (re)initialise the object.

=cut

sub initialise ($$) {
  my $this = shift;
  $this->{'processor'} = shift;
  $this->Minimum(0);
  return $this;
  }

=item $parserp = new ParserArgs::Board($processor);

Create a new instance

=cut

sub new ($$) { TSH::Utility::new(@_); }

=item $argument_description = $this->Parse($line_parser)

Return the checked value of the command-line argument,
or () if the argument is invalid.

=cut

sub Parse ($$) {
  my $this = shift;
  my $line_parser = shift;
  return $this->SUPER::Parse($line_parser);
  }

=item $argument_description = $this->Usage()

Briefly describe this argument's usage (in a word or hyphenated phrase)

=cut

sub Usage ($) {
  my $this = shift;
  return 'board';
  }

=back

=head1 BUGS

None known.

=cut

1;



