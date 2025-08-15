#!/usr/bin/perl

# Copyright (C) 2005 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::ParseArgs::Round0;

use strict;
use warnings;

use TSH::ParseArgs::Integer;
use TSH::Utility;

=pod

=head1 NAME

TSH::ParseArgs::Round0 - handle a command-line argument that should be a tournament round number or 0

=head1 SYNOPSIS

  my $parser = new TSH::ParseArgs::Round0;

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
  $this->Minimum(0);
  $this->Description('a round number or 0');
  return $this;
  }

=item $parserp = new ParserArgs::Round0

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
  $this->Maximum(10000);
  $line_parser->SetShared('round_error', 'epabr');
  my $value = $line_parser->GetArg();
  $line_parser->UnGetArg($value);
  $line_parser->SetShared('round_value', $value);
  return $this->SUPER::Parse($line_parser);
  }

=item $argument_description = $this->Usage()

Briefly describe this argument's usage (in a word or hyphenated phrase)

=cut

sub Usage ($) {
  my $this = shift;
  return 'round-or-0';
  }

=back

=cut

1;



