#!/usr/bin/perl

# Copyright (C) 2005 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::ParseArgs::RoundRange;

use strict;
use warnings;

use TSH::Utility;

=pod

=head1 NAME

TSH::ParseArgs::RoundRange - handle a command-line argument that should be a ragne of round numbers

=head1 SYNOPSIS

  my $parser = new TSH::ParseArgs::RoundRange;

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
    $line_parser->Error("You need to specify a range of rounds (e.g., 2-5) with this command.");
    return ();
    }
  if ($value =~ /^(\d+)(?:-(\d+))?$/) {
    return (defined $2)
      ? ($1,$2)
      : ($1,$1);
    }
  else {
    $line_parser->Error("This doesn't look like a range of rounds to me. Try something like 2-5 instead.");
    return ();
    }
  }

=item $argument_description = $this->Usage()

Briefly describe this argument's usage (in a word or hyphenated phrase)

=cut

sub Usage ($) {
  my $this = shift;
  return 'round-range';
  }

=back

=cut

1;
