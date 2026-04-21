#!/usr/bin/perl

# Copyright (C) 2005 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::ParseArgs::OptionalInteger;

use strict;
use warnings;

use TSH::Utility;

=pod

=head1 NAME

TSH::ParseArgs::OptionalInteger - handle a command-line argument that should be an integer but may be omitted

=head1 SYNOPSIS

  my $parser = new TSH::ParseArgs::OptionalInteger;
  $parser->Maximum(10);
  $parser->Minimum(1);

=head1 ABSTRACT

This Perl module is used by C<ParseArgs.pm> to ignore command-line arguments.

=cut

=head1 DESCRIPTION

=over 4

=cut

sub initialise ($);
sub Maximum ($;$);
sub Minimum ($;$);
sub new ($);
sub Parse ($$);
sub Usage ($);

=item $parserp->initialise();

Used internally to (re)initialise the object.

=cut

sub initialise ($) {
  my $this = shift;
  $this->{'type_optionalinteger_description'} = 'an integer' 
    unless $this->{'type_optionalinteger_description'};
  return $this;
  }

=item $max = $parserp->Maximum();
=item $old_max = $parserp->Maximum($new_max);

Get/set the maximum allowed value for this type of integer.

=cut

sub Maximum ($;$) 
  { TSH::Utility::GetOrSet('type_optionalinteger_maximum', @_); }

=item $min = $parserp->Minimum();
=item $old_min = $parserp->Minimum($new_min);

Get/set the minimum allowed value for this type of integer.

=cut

sub Minimum ($;$) 
  { TSH::Utility::GetOrSet('type_optionalinteger_minimum', @_); }

=item $parserp = new ParserArgs::Round

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
  if ($value !~ /^-?\d+$/) {
    $line_parser->UnGetArg($value);
    return ();
    }
  if ((exists $this->{'type_optionalinteger_minimum'})
    && $this->{'type_optionalinteger_minimum'} > $value) {
    return ();
    }
  if ((exists $this->{'type_optionalinteger_maximum'})
    && $this->{'type_optionalinteger_maximum'} < $value) {
    return ();
    }
# warn "returning: (@{$line_parser->{'argv'}}):$line_parser->{'argi'} $value";
  return $value;
  }

=item $argument_description = $this->Usage()

Briefly describe this argument's usage (in a word or hyphenated phrase)

=cut

sub Usage ($) {
  my $this = shift;
  return '[integer]';
  }

=back

=cut

1;




