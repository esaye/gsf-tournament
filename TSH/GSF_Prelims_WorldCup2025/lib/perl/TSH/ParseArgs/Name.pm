#!/usr/bin/perl

# Copyright (C) 2016 John J. Chew, III <poslfit@gmail.com>
# All Rights Reserved

package TSH::ParseArgs::Name;

use strict;
use warnings;

use TSH::Utility;

=pod

=head1 NAME

TSH::ParseArgs::Name - handle a command-line argument that is a player name

=head1 SYNOPSIS

  my $parser = new TSH::ParseArgs::Name;

=head1 ABSTRACT

This Perl module is used by C<ParseArgs.pm> to match full player names (not IDs or partial names) as command-line arguments.

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
  $this->{'type_name_description'} = 'a player name' 
    unless $this->{'type_name_description'};
  return $this;
  }

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
  my (@words);
  my $value;
  while (1) {
    $value = $line_parser->GetArg();
    last unless defined $value;
    if ($value =~ /^-?\d+$/) {
      $line_parser->UnGetArg($value);
      last;
      }
    push(@words, $value);
    }
  return @words;
  }

=item $argument_description = $this->Usage()

Briefly describe this argument's usage (in a word or hyphenated phrase)

=cut

sub Usage ($) {
  my $this = shift;
  return 'full-player-name';
  }

=back

=cut

1;




