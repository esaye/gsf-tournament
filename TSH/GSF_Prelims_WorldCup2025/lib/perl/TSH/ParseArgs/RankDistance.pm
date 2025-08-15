#!/usr/bin/perl

# Copyright (C) 2005 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::ParseArgs::RankDistance;

use strict;
use warnings;

use TSH::ParseArgs::Integer;
use TSH::Utility;

=head1 NAME

TSH::ParseArgs::RankDistance - handle a command-line argument that should be a number of ranks' separation in FP(n)

=head1 SYNOPSIS

  my $parser = new TSH::ParseArgs::RankDistance;

=head1 ABSTRACT

This Perl module is used by C<ParseArgs.pm> to ignore command-line arguments.

=cut

=head1 DESCRIPTION

=over 4

=cut

our(@ISA) = qw(TSH::ParseArgs::Integer);

sub initialise ($);
sub new ($);
sub Parse ($$);
sub Usage ($);

=item $parserp->initialise();

Used internally to (re)initialise the object.

=cut

sub initialise ($) {
  my $this = shift;
  $this->Minimum(1);
  $this->Description("a number of ranks' separation preferred");
  return $this;
  }

=item $parserp = new ParserArgs::RankDistance

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
  # just in case it's changed recently
  $this->Maximum( 10000);
  return $this->SUPER::Parse($line_parser);
  }

=item $argument_description = $this->Usage()

Briefly describe this argument's usage (in a word or hyphenated phrase)

=cut

sub Usage ($) {
  my $this = shift;
  return 'rank-distance';
  }

=back

=cut

1;
