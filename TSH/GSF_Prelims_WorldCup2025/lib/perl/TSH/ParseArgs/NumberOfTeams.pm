#!/usr/bin/perl

# Copyright (C) 2011 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::ParseArgs::NumberOfTeams;

use strict;
use warnings;

use TSH::ParseArgs::Integer;
use TSH::Utility;

=pod

=head1 NAME

TSH::ParseArgs::NumberOfTeams - handle a command-line argument that should be a number of teams

=head1 SYNOPSIS

  my $parser = new TSH::ParseArgs::NumberOfTeams;

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
  $this->Minimum(2);
# $this->Maximum(3);
  $this->Description('a number of teams');
  return $this;
  }

=item $parserp = new ParserArgs::NumberOfTeams

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
  return $this->SUPER::Parse($line_parser);
  }

=item $argument_description = $this->Usage()

Briefly describe this argument's usage (in a word or hyphenated phrase)

=cut

sub Usage ($) {
  my $this = shift;
  return 'number-of-teams';
  }

=back

=cut

=head1 BUGS

None known.

=cut

1;

