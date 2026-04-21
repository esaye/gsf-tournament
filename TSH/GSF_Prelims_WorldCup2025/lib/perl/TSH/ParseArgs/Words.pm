#!/usr/bin/perl

# Copyright (C) 2005 John J. Chew, III <jjchew@math.utoronto.ca>
# All Rights Reserved

package TSH::ParseArgs::Words;

use strict;
use warnings;

use TSH::Utility;

=pod

=head1 NAME

TSH::ParseArgs::Words - match one or more played words on the command line

=head1 SYNOPSIS

  my $parser = new TSH::ParseArgs::Words;

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

=item $parserp = new ParserArgs::Words

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
  my $value;
  while (1) {
    $value = $line_parser->GetArg();
    last unless defined $value;
    if ($value =~ /^([a-z]{2,})/i) {
      push(@words, $value);
      }
    else {
      $line_parser->UnGetArg($value);
      last;
      }
    }
  if (@words) {
    return @words;
    }
  else {
    my $example = '';
    $example = " ($value is not a word.)" if $value;
    $line_parser->Error("You need to specify a word with this command.$example");
    return ();
    }
  }

=item $argument_description = $this->Usage()

Briefly describe this argument's usage (in a word or hyphenated phrase)

=cut

sub Usage ($) {
  my $this = shift;
  return 'word(s)';
  }

=back

=head1 BUGS

None known.

=cut

1;
