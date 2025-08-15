#!/usr/bin/perl

# Copyright (C) 2005 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::ParseArgs::Integer;

use strict;
use warnings;

use TSH::Utility;

=pod

=head1 NAME

TSH::ParseArgs::Integer - handle a command-line argument that should be an integer

=head1 SYNOPSIS

  my $parser = new TSH::ParseArgs::Integer;
  $parser->Description('an integer');
  $parser->Maximum(10);
  $parser->Minimum(1);

=head1 ABSTRACT

This Perl module is used by C<ParseArgs.pm> to ignore command-line arguments.

=cut

=head1 DESCRIPTION

=over 4

=cut

sub Description ($;$);
sub initialise ($);
sub Maximum ($;$);
sub Minimum ($;$);
sub new ($);
sub Parse ($$);
sub Usage ($);

=item $desc = $parserp->Description();
=item $old_desc = $parserp->Description($new_desc);

Get/set the description of this type of integer, used in some
diagnostic messages.

=cut

sub Description ($;$) 
  { TSH::Utility::GetOrSet('type_integer_description', @_); }

=item $parserp->initialise();

Used internally to (re)initialise the object.

=cut

sub initialise ($) {
  my $this = shift;
  $this->{'type_integer_description'} = 'an integer' 
    unless $this->{'type_integer_description'};
  return $this;
  }

=item $max = $parserp->Maximum();
=item $old_max = $parserp->Maximum($new_max);

Get/set the maximum allowed value for this type of integer.

=cut

sub Maximum ($;$) { TSH::Utility::GetOrSet('type_integer_maximum', @_); }

=item $min = $parserp->Minimum();
=item $old_min = $parserp->Minimum($new_min);

Get/set the minimum allowed value for this type of integer.

=cut

sub Minimum ($;$) { TSH::Utility::GetOrSet('type_integer_minimum', @_); }

=item $parserp = new ParserArgs::Round

Create a new instance

=cut

sub new ($) { TSH::Utility::new(@_); }

=item $argument_description = $parserp->Parse($line_parser)

Return the checked value of the command-line argument,
or () if the argument is invalid.

=cut

sub Parse ($$) {
  my $this = shift;
  my $line_parser = shift;
  my $value = $line_parser->GetArg();
  if (!defined $value) {
    $line_parser->Error("You need to specify $this->{'type_integer_description'} with this command.");
    return ();
    }
  if ($value !~ /^-?\d+$/) {
    $line_parser->Error("$value doesn't look like $this->{'type_integer_description'} to me.");
    return ();
    }
  if ((exists $this->{'type_integer_minimum'})
    && $this->{'type_integer_minimum'} > $value) {
    $line_parser->Error("$value is too small to be $this->{'type_integer_description'}.");
    return ();
    }
  if ((exists $this->{'type_integer_maximum'})
    && $this->{'type_integer_maximum'} < $value) {
    $line_parser->Error("$value is too large to be $this->{'type_integer_description'}.");
    return ();
    }
  return $value;
  }

=item $argument_description = $this->Usage()

Briefly describe this argument's usage (in a word or hyphenated phrase)

=cut

sub Usage ($) {
  my $this = shift;
  return 'integer';
  }

=back

=cut

1;



